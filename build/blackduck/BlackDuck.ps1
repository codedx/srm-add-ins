#
# This script orchestrates a Black Duck scan, handling both full and rapid scans. Both scan 
# types depend on a Code Dx Project Secret named blackduck-credential with a field named
# api-token (mounted at /path/to/workdir/workflow-secrets/blackduck-credential/api-token)
#
# Step 1: Unzip source
# Step 2: Run Black Duck Detect on source
# Step 3: Fetch result
#         3a: Fetch JSON result (rapid scan model)
#         3b: Run Black-Duck-Scrape to pull results (full scan model)
#
param (
	[Parameter(Mandatory=$true)][string] $sourcePath,
	[Parameter(Mandatory=$true)][string] $scanRequestFilePath
)

Set-PSDebug -Strict
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

$global:PSNativeCommandArgumentPassing='Legacy'

. ./add-in.ps1

function Get-CertCheckOptions($skipCertCheck) {

	$options = @{SkipCertificateCheck = $false}
	if ($skipCertCheck) {
		$options['SkipCertificateCheck'] = $true
	}
	$options
}

function Get-BearerToken($baseUrl, $apiToken, $skipCertCheck) {

	if (-not ($baseUrl.EndsWith('/'))) {
		$baseUrl = "$baseUrl/"
	}

	$options = Get-CertCheckOptions $skipCertCheck

	$tokenHeader = @{'Authorization'="token $apiToken"}
	$authenticateResponse = Invoke-WebRequest -Method POST -Uri "$($baseUrl)api/tokens/authenticate" -Headers $tokenHeader @options

	$bearerJson = [Text.Encoding]::ASCII.GetString($authenticateResponse.Content) | ConvertFrom-Json
	@{'Authorization'="Bearer $($bearerJson.bearerToken)"}
}

function Get-ProjectVersions([string] $baseUrl, $bearerHeader, $options, [string] $projectId, [int] $limit) {

	$projectVersions = Invoke-WebRequest -Uri "$($baseUrl)api/projects/$projectId/versions?limit=$limit" -Headers $bearerHeader @options
	[Text.Encoding]::ASCII.GetString($projectVersions.Content) | ConvertFrom-Json
}

function Get-ProjectAndVersion($baseUrl, $apiToken, $projectName, $versionName, $skipCertCheck) {

	if (-not ($baseUrl.EndsWith('/'))) {
		$baseUrl = "$baseUrl/"
	}

	$options = Get-CertCheckOptions $skipCertCheck

	$bearerHeader = Get-BearerToken $baseUrl $apiToken $skipCertCheck

	$projectNameQuery =  [Web.HttpUtility]::UrlEncode("name:$projectName")
	$projects = Invoke-WebRequest -Uri "$($baseUrl)api/projects?q=$projectNameQuery" @options -Headers $bearerHeader
	$projectsJson = [Text.Encoding]::ASCII.GetString($projects.Content) | ConvertFrom-Json

	Write-Verbose "Found project count of $($projectsJson.totalCount)."

	$projectItem = $projectsJson.items | Where-Object { $_.name -eq $projectName }
	if ($null -eq $projectItem) {
		throw "Expected to find a single project with name '$projectName'."
	}

	$projectHref = $projectItem._meta.href
	Write-Verbose "Found project HREF $projectHref"

	$projectId = $projectHref -split '/' | Select-Object -Last 1
	$projectVersionsJson = Get-ProjectVersions $baseUrl $bearerHeader $options $projectId 1

	$totalProjectVersions = $projectVersionsJson.totalCount
	Write-Verbose "Found $totalProjectVersions project version(s)"

	if ($totalProjectVersions -gt 1) {
		$projectVersionsJson = Get-ProjectVersions $baseUrl $bearerHeader $options $projectId $totalProjectVersions
	}

	$versionData = $projectVersionsJson | ForEach-Object { $_.items } | Select-Object 'versionName','_meta' | Where-Object { $_.versionName -eq $versionName }
	if ($null -eq $versionData) {
		throw "Expected to find a project version with name '$versionName'."
	}

	$versionHref = $versionData._meta.href
	Write-Verbose "Found version HREF $versionHref"

	$versionId = $versionHref -split '/' | Select-Object -Last 1
	$projectId,$versionId
}

function Get-RapidScanResult($baseUrl, $apiToken, $skipCertCheck, $scanId, $outputFile) {

	if (-not ($baseUrl.EndsWith('/'))) {
		$baseUrl = "$baseUrl/"
	}

	$options = Get-CertCheckOptions $skipCertCheck

	$header = Get-BearerToken $baseUrl $apiToken $skipCertCheck
	$header.Accept = 'application/vnd.blackducksoftware.scan-5+json'

	Invoke-WebRequest -Uri "$($baseUrl)api/developer-scans/$scanId/full-result" @options -Headers $header -OutFile $outputFile
}

function Get-DetectStringOption([string] $tomlParameterName, [string] $detectParameterName, [string] $tomlParameterValue, $options, $allowableValues) {

	$detectParameterNameRegex = [regex]::escape($detectParameterName)
	if(($options -match "^\s*--$detectParameterNameRegex=.*$").count -gt 0) {
		throw "$tomlParameterName and --$detectParameterName options both set. Only one may be set"
	}
	if ($null -ne $allowableValues -and $allowableValues -cnotcontains $tomlParameterValue) {
		throw "$tomlParameterName $tomlParameterValue is invalid because it must be one of these: $allowableValues"
	}
	"--$detectParameterName=`"$tomlParameterValue`""
}

write-verbose "Reading scan request file ($scanRequestFilePath)..."
$scanRequestConfig = Get-Config $scanRequestFilePath

$workDirectory = $scanRequestConfig.request.workdirectory
write-verbose "Using work directory $workDirectory"

$blackDuckProjectName = $scanRequestConfig.blackduck.projectName
$blackDuckVersionName = $scanRequestConfig.blackduck.versionName

if ($blackDuckVersionName -eq "" -and $scanRequestConfig.blackduck.useBranchForVersion) {
	$blackDuckVersionName = $scanRequestConfig.request.branchName
}

$blackDuckApiToken = Get-FileContents (join-path $workDirectory 'workflow-secrets/blackduck-credential/api-token')

Set-Tlsv12

$blackDuckBaseUrl = $scanRequestConfig.blackduck.baseurl

$sourceDirectory = join-path $scanRequestConfig.request.workdirectory 'source'

write-verbose "Step 1: Unpack source code..."
Expand-SourceArchive $sourcePath $sourceDirectory -restoreGitDirectory

$sourceCode = $scanRequestConfig.'source-code'
$sourceDirectory = Push-BaseSourceCodeDirectory $sourceDirectory $sourceCode.relativeDirectory $sourceCode.projectFileDirectoryPatterns

Add-TrustedCertsJava $scanRequestConfig.request.workdirectory '/etc/ssl/certs/java/cacerts' 'changeit'

$detectOptions = $scanRequestConfig.detect.options
if($null -eq $detectOptions) {
	$detectOptions = @()
}

# List of regexes for options keys we want to disallow
#
# Detect documentation (from an earlier version) explains how parameter precedence is based on
# Spring Boot - command-line arguments take precedence of YAML configuration, so it's 
# unnecessary to check for conflicting YAML parameter values.
#
$invalidOptionRegex = @(
	'blackduck\.url',
	'blackduck\.api\.token',
	'detect\.wait\.for\.results',
	'detect\.cleanup',
	'detect\.source\.path',
	'detect\.output\.path',
	'detect\.phone\.home\.passthrough\.invoked\.by\.image',
	'logging\.level\.com\.synopsys\.integration',
	'logging\.level\.detect',
	'detect\.blackduck\.scan\.mode',
	'detect\.blackduck\.rapid\.compare\.mode'
) -join '|'
# Check that the user didn't set any options that we do already, with the exception of the project
# and version names, which are handled below.
$invalidOptions = $detectOptions -match "^\s*--($invalidOptionRegex)=.*$"
if($invalidOptions.count -gt 0) {
	write-verbose "The following detect options conflict with options set by Code Dx: $invalidOptions"
	throw "Invalid options"
}

# The project and version names don't need to be provided -- if either are absent Black Duck will
# pick a name for them. If a user wants to just provide all the args in the options field, they can
# technically set the project and version names there too, but we should at least make sure it's
# not also set in the corresponding config field.
if (-not [string]::IsNullOrWhiteSpace($blackDuckProjectName)) {
	$detectOptions += Get-DetectStringOption 'blackduck.projectName' 'detect.project.name' $blackDuckProjectName $detectOptions
}
if (-not [string]::IsNullOrWhiteSpace($blackDuckVersionName)) {
	$detectOptions += Get-DetectStringOption 'blackduck.versionName' 'detect.project.version.name' $blackDuckVersionName $detectOptions
}

# INFO, DEBUG, or TRACE is required because Rapid Scan mode depends on this INFO log output:
# Uploaded Rapid Scan: https://sig-bd-hub-test.app.blackduck.com/api/developer-scans/$scanId
$validLogLevels = 'INFO','DEBUG','TRACE'

$logLevel = [string]::IsNullOrWhiteSpace($scanRequestConfig.blackduck.logLevel) ? 'INFO' : $scanRequestConfig.blackduck.logLevel

$detectOptions += Get-DetectStringOption 'blackduck.logLevel' 'logging.level.com.synopsys.integration' $logLevel $detectOptions $validLogLevels
$detectOptions += Get-DetectStringOption 'blackduck.logLevel' 'logging.level.detect' $logLevel $detectOptions $validLogLevels

if ($scanRequestConfig.blackduck.isRapidScan) {

	$detectOptions += Get-DetectStringOption 'blackduck.isRapidScan' 'detect.blackduck.scan.mode' 'RAPID' $detectOptions
	if (-not [string]::IsNullOrWhiteSpace($scanRequestConfig.blackduck.rapidScanComparison)) {
		$detectOptions += Get-DetectStringOption 'blackduck.rapidScanComparison' 'detect.blackduck.rapid.compare.mode' $scanRequestConfig.blackduck.rapidScanComparison $detectOptions @('ALL','BOM_COMPARE','BOM_COMPARE_STRICT')
	}
}

$optionsYaml = $scanRequestConfig.detect.optionsYaml
if ($optionsYaml -ne "") {

	$optionsYamlPath = join-path $workDirectory 'detect-options.yaml'
	$optionsYaml | out-file $optionsYamlPath
	$detectOptions += "--spring.config.location=""$optionsYamlPath"""
}

if ([Convert]::ToBoolean($scanRequestConfig.detect.skipBlackDuckPhoneHome)) {
	[Environment]::SetEnvironmentVariable("SYNOPSYS_SKIP_PHONE_HOME", "true")
}

$preDetectCmdLine = $scanRequestConfig.detect.preDetectCmdLine
if (-not ([string]::IsNullOrWhitespace($preDetectCmdLine))) {
	write-verbose "Running prebuild command $preDetectCmdLine..."
	Invoke-Expression -Command $preDetectCmdLine
}

$outputDirectory = join-path $workDirectory 'output'
$logFile = '/tmp/detect.log'

write-verbose 'Step 3: Running synopsys-detect.jar with specified command arguments...'
java -jar /synopsys-detect.jar --blackduck.url=$blackDuckBaseUrl --blackduck.api.token=$blackDuckApiToken --detect.wait.for.results=true --detect.cleanup=false --detect.source.path=$sourceDirectory --detect.output.path=$outputDirectory --detect.phone.home.passthrough.invoked.by.image=true @($detectOptions) | Tee-Object $logFile

# For possible exit codes, see https://documentation.blackduck.com/bundle/detect/page/troubleshooting/exit-codes.html
$detectSuccessful = $LASTEXITCODE -eq 0 -or ($scanRequestConfig.blackduck.isRapidScan -and $LASTEXITCODE -eq 3) # FAILURE_POLICY_VIOLATION

# The status file in $outputDirectory/runs/<date-time>/status/status.json contains the location
# of the resulting Black Duck project
$runDirectory = (Get-ChildItem (join-path $outputDirectory 'runs') | Select-Object -First 1).FullName
$detectStatusFile = join-path $runDirectory 'status/status.json'
$detectStatusContent = Get-Content $detectStatusFile

Write-Verbose ($detectStatusContent -join "`n")

if (-not $detectSuccessful) {
	throw "Detect failed with exit code $LASTEXITCODE"
}

$statusJson = $detectStatusContent | ConvertFrom-Json

$reportOutputPath = $scanRequestConfig.request.resultfilepath

if ($scanRequestConfig.blackduck.isRapidScan) {

	$logFileContents = Get-Content $logFile

	$foundScanId = ($logFileContents -join "`n") -match 'Uploaded\sRapid\sScan:\shttp.+/developer-scans/(?<scanId>.+)'

	if (-not $foundScanId) {
		$logFileContents | Write-Verbose
		throw "Unable to find scan ID in $logFile"
	}

	$scanId = $matches.scanId
	write-verbose "Step 3a: Downloading developer-scan for scan ID $scanId..."
	Get-RapidScanResult $blackDuckBaseUrl $blackDuckApiToken $scanRequestConfig.blackduck.skipCertCheck $scanId $reportOutputPath

} else {

	# BD can pick a project name and version, so rely on what's in status.json
	$statusProjectName = $statusJson.projectName
	$statusProjectVersion = $statusJson.projectVersion

	$projectAndVersion = Get-ProjectAndVersion $blackDuckBaseUrl $blackDuckApiToken $statusProjectName $statusProjectVersion $scanRequestConfig.blackduck.skipCertCheck
	if ($projectAndVersion.Length -ne 2) {
		throw "Failed to find project ID and/or version ID for project/version $statusProjectName/$statusProjectVersion"
	}

	$projectId = $projectAndVersion[0]
	$versionId = $projectAndVersion[1]

	write-verbose "Step 3b: Invoking Black Duck Scraper on project $projectId version $versionId..."
	$tmpDir = Join-Path $scanRequestConfig.request.workDirectory "tmp_dir"
	java -jar /opt/codedx/blackduck/bin/Black-Duck-Scrape.jar -u $blackDuckBaseUrl -p $projectId -v $versionId -o $reportOutputPath -t $tmpDir -a $blackDuckApiToken @($scanRequestConfig.scraper.options)
}
