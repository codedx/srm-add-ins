#
# This script takes the following steps to automate Burp Suite.
#
# Step 1: Start Burp Suite, loading the Generate Report extension
# Step 2: Use Burp Suite's API to start a scan
# Step 3: Wait for the scan to complete
# Step 4: Use the Generate Report extension to create a Burp Suite XML report
#
param (
	[Parameter(Mandatory=$true)][string] $burpSuiteJarPath,
	[Parameter(Mandatory=$true)][string] $generateReportBurpExtensionPath,
	[Parameter(Mandatory=$true)][string] $scanRequestFilePath,
	[string] $testConnectPath,
	[int] $reportWaitMinutes = 5
)

Set-PSDebug -Strict
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

. ./add-in.ps1

function Wait-ProjectLoaded([string] $port, [string] $key, [datetime] $giveUpTimeUtc) {

	$projectLoaded = $false
	do {
		try {
			Start-Sleep -Seconds 1

			Write-Verbose 'Testing project load by sending web request for invalid task ID...'
			Invoke-WebRequest "http://localhost:$port/$key/v0.1/scan/0" # 0 is an invalid task ID
		}
		catch {
			Write-Verbose $_
			$errorDetails = $null
			try { $errorDetails = $_.ErrorDetails.Message | convertfrom-json } catch {
				Write-Verbose "Failed to parse error details: $_"
			}
			Write-Verbose "Error details: $errorDetails"
			$projectLoaded = $errorDetails.type -eq 'ClientError' -and $errorDetails.error -eq 'Task ID not found'
		}
	}
	until ($projectLoaded -or [datetime]::UtcNow -ge $giveUpTimeUtc)
}

function Wait-RemoveItem([string] $path) {

	$stopTime = [datetime]::now.AddMinutes(1)
	do {
		try {
			Remove-Item $path
			break
		}
		catch {
			Write-Verbose "Retrying removal of $path after error: $_"
		}
	}
	until ([datetime]::Now -lt $stopTime)
}

function Test-InputPaths([string[]] $paths) {
	$paths | ForEach-Object {
		if (-not (Test-Path $_ -PathType Leaf)) {
			Write-Host "Unable to find path $_"
			exit 1
		}
	}
}

if ($burpSuiteJarPath -like '*community*') {
	Write-Host "The Burp Suite REST API is unsupported by the Community edition"
	exit 2
}

if ($testConnectPath -eq "") {
	$testConnectPath = join-path $PSScriptRoot 'testconnect'
}

Write-Verbose 'Validating input file paths...'
Test-InputPaths ($burpSuiteJarPath, $generateReportBurpExtensionPath, $scanRequestFilePath, $testConnectPath)

Write-Verbose "Reading scan request file ($scanRequestFilePath)..."
$scanRequestConfig = Get-Config $scanRequestFilePath

$workDirectory = $scanRequestConfig.request.workdirectory
write-verbose "Using work directory $workDirectory"

$workflowSecretsDirectory = join-path $workDirectory 'workflow-secrets'

$apiKeyPath = join-path $workflowSecretsDirectory 'burp-suite-api-key/key'
$apiHashedKeyPath = join-path $workflowSecretsDirectory 'burp-suite-api-key/hashed-key'

Write-Verbose 'Validating input file paths...'
Test-InputPaths ($apiKeyPath, $apiHashedKeyPath)

$apiPort = $scanRequestConfig.scan.apiPort
$apiOptionsPath = [io.path]::GetTempFileName()
Write-Verbose "Storing user_options to enable REST API at $apiOptionsPath..."
@"
{
	"user_options":{
		"misc":{
			"api":{
				"address":"",
				"enabled":true,
				"insecure_mode": false,
				"keys":[{"created":$([DateTimeOffset]::Now.ToUnixTimeSeconds()),"enabled":true,"hashed_key":"$(Get-FileContents $apiHashedKeyPath)","name":"user-generated-key"}],
				"listen_mode":"loopback_only",
				"port":$apiPort
			}
		}
	}
}
"@ | Out-File $apiOptionsPath -Encoding ascii

$extenderOptionsPath = [io.path]::GetTempFileName()
Write-Verbose "Storing user_options to enable Generate Report extension at $extenderOptionsPath..."
@"
{
	"user_options":{
		"extender":{
			"extensions":[
				{
					"errors":"console",
					"extension_file":"$($generateReportBurpExtensionPath.Replace('\','\\'))",
					"extension_type":"java",
					"loaded":true,
					"name":"Generate Report Extender",
					"output":"console"
				}
			]
		}
	}
}
"@ | Out-File $extenderOptionsPath -Encoding ascii

Write-Verbose 'Locating java path...'
$javaPath = (Get-Command java).Source

$burpSuiteProjectFile = Join-Path ([io.path]::GetTempPath()) ([guid]::NewGuid())
$argumentList = @('-jar', $burpSuiteJarPath, 
	'-Djava.awt.headless=true',
	"--user-config-file=$apiOptionsPath",
	"--user-config-file=$extenderOptionsPath",
	"--project-file=$burpSuiteProjectFile",
	'--unpause-spider-and-scanner')

$reportOutputPath = $scanRequestConfig.request.resultfilepath
$reportOutputDirectory = split-path $reportOutputPath
if ($reportOutputDirectory -eq '') {
	$reportOutputDirectory = (get-location).path
}

Write-Verbose "Configuring environment variable to generate report in directory $reportOutputDirectory..."
[environment]::SetEnvironmentVariable('GENERATE_REPORT_DIRECTORY', $reportOutputDirectory)

Write-Verbose "Launching Burp Suite with $javaPath and argument list: $argumentList..."
$burpSuiteProcess = Start-Process -FilePath $javaPath -ArgumentList $argumentList -PassThru

Write-Verbose "Waiting for API to listen on port $apiPort..."
$connectTimeoutSeconds = 2 * 60
& $testconnectPath -port $apiPort -timeout $connectTimeoutSeconds
if ($LASTEXITCODE -ne 0) {
	Write-Host "Timed out after $connectTimeoutSeconds seconds waiting for port $apiPort"
	exit 3
}

$apiKey = Get-FileContents $apiKeyPath

Write-Verbose "Waiting for project load..."
Wait-ProjectLoaded $apiPort $apiKey ([datetime]::UtcNow.AddMinutes(2))

$scanRequest = @{
	'urls' = $scanRequestConfig.scan.urls
}

Write-Verbose "Processing scan name..."
if ($scanRequestConfig.scan.name -ne '') {
	Write-Verbose "Adding name: $($scanRequestConfig.scan.name)..."
	$scanRequest['name'] = $scanRequestConfig.scan.name
}

$hasScopeIncludes = $scanRequestConfig.scan.includeSimpleScope.length -gt 0
$hasScopeExcludes = $scanRequestConfig.scan.excludeSimpleScope.length -gt 0

if ($hasScopeIncludes -or $hasScopeExcludes) {
	$scanRequest['scope'] = @{}
}

Write-Verbose 'Processing scope includes...'
if ($hasScopeIncludes) {
	$includes = @()
	$scanRequestConfig.scan.includeSimpleScope | foreach-object {
		Write-Verbose "Adding include scope: $_..."
		$includes += @{rule=$_}
	}
	$scanRequest['scope']['include'] = $includes
	$scanRequest['scope']['type'] = 'SimpleScope'
}

Write-Verbose 'Processing scope excludes...'
if ($hasScopeExcludes) {
	$excludes = @()
	$scanRequestConfig.scan.excludeSimpleScope | foreach-object {
		Write-Verbose "Adding exclude scope: $_..."
		$excludes += @{rule=$_}
	}
	$scanRequest['scope']['exclude'] = $excludes
	$scanRequest['scope']['type'] = 'SimpleScope'
}

Write-Verbose 'Processing named configurations...'
if ($scanRequestConfig.scan.namedConfigurations.Length -gt 0) {
	$configurations = @()
	$scanRequestConfig.scan.namedConfigurations | foreach-object {
		Write-Verbose "Adding named configuration: $_..."
		$configurations += @{name=$_; type='NamedConfiguration'}
	}
	$scanRequest['scan_configurations'] = $configurations
}

Write-Verbose 'Processing credentials...'
$credentials = @()
get-childitem $workflowSecretsDirectory | ForEach-Object {
	$username = join-path $_.FullName 'username'
	$password = join-path $_.FullName 'password'
	if ((test-path $username -type Leaf) -and (test-path $password -type Leaf)) {
		Write-Verbose 'Adding credential...'
		$credentials += @{
			username=Get-FileContents $username
			password=Get-FileContents $password
		}
	}
}
if ($credentials.Length -gt 0) {
	$scanRequest['application_logins'] = $credentials
}
 
$apiKey = Get-FileContents $apiKeyPath
$body = ConvertTo-Json $scanRequest -Depth 3
$response = Invoke-WebRequest "http://localhost:$apiPort/$apiKey/v0.1/scan" -Method Post -Body $body

$taskId = $response.Headers.Location 
Write-Verbose "Scan started with task ID $taskId"

$keepWaitingStatusList = @('initializing','crawling','auditing')
$results = Invoke-RestMethod "http://localhost:$apiPort/$apiKey/v0.1/scan/$taskId"
while ($keepWaitingStatusList -contains $results.scan_status) {
	Start-Sleep -Seconds 5
	$results = Invoke-RestMethod "http://localhost:$apiPort/$apiKey/v0.1/scan/$taskId"
	Write-Verbose "At $([datetime]::UtcNow) UTC, status is $($results.scan_status)`n  with scan metrics $($results.scan_metrics)`n  and message '$($results.message)'"
}

Write-Verbose "Stopped waiting on scan result. Status is $($results.scan_status) with scan metrics $($results.scan_metrics)"
if ($results.scan_status -ne 'succeeded') {
	Write-Host 'Scan did not succeed!'
	exit 4
}

$reportFile = split-path $reportOutputPath -leaf
$reportFileRequestPath = join-path $reportOutputDirectory ('generate-report-{0}' -f $reportFile)

Write-Verbose "Request report with $reportFileRequestPath..."
Remove-Item $reportFileRequestPath -ErrorAction Ignore; New-Item $reportFileRequestPath -ItemType file -Force

$stopWaitingForReportTime = [datetime]::Now.AddMinutes($reportWaitMinutes)
while (test-path $reportFileRequestPath -PathType Leaf) {
	if ([datetime]::Now -ge $stopWaitingForReportTime) {
		throw "Giving up because the report is taking too long to generate (waited $reportWaitMinutes minutes)"
	}
	Write-Verbose 'Waiting for report...'
	Start-Sleep -Seconds 2
}

Write-Verbose 'Stopping Burp Suite...'
Stop-Process $burpSuiteProcess.Id

Write-Verbose 'Waiting for Burp Suite to stop...'
Wait-Process $burpSuiteProcess.Id -ErrorAction Ignore

Write-Verbose 'Cleaning up temp files...'
Wait-RemoveItem $apiOptionsPath -Force
Wait-RemoveItem $extenderOptionsPath -Force
Wait-RemoveItem $burpSuiteProjectFile -Force

Write-Verbose 'Done'
