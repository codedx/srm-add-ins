#
# This script takes the following steps to obtain a report from a Checkmarx scanner.
#
# Step 1: Obtain bearer token
# Step 2: Upload source
# Step 3: Start scan
# Step 4: Wait for scan to complete
# Step 5: Create new XML report
# Step 6: Wait for report to complete
# Step 7: Fetch XML report
#
param (
	[Parameter(Mandatory=$true)][string] $scanRequestFilePath
)

Set-PSDebug -Strict
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

. $PSScriptRoot/add-in.ps1

class Token {

	[string]   $accessToken
	[DateTime] $expirationTime

	Token([string] $accessToken, [int] $tokenLifetimeInSeconds) {
		$this.accessToken = $accessToken
		$this.expirationTime = [DateTime]::Now.AddSeconds($tokenLifetimeInSeconds)
	}

	[bool] isExpired() {
		return [DateTime]::Now -ge $this.expirationTime
	}

	[bool] isValid() {
		return -not $this.isExpired()
	}
}

function New-CheckmarxToken([string] $tokenUrl, [string] $checkmarxUsername, [string] $checkmarxPwd) {

	# Note: The Checkmarx documentation states that this parameter must have the value specified here
	$clientSecret = '014DF517-39D1-4453-B7B3-9930C563627C'

	$tokenBody = @{
		'username'=$checkmarxUsername
		'password'=$checkmarxPwd
		'grant_type'='password'
		'scope'='sast_rest_api'
		'client_id'='resource_owner_client'
		'client_secret'=$clientSecret
	}

	write-verbose "Obtaining bearer token from $tokenUrl..."
	Invoke-RestMethod -Uri $tokenUrl `
		-Method Post `
		-Body $tokenBody
}

function Get-CheckmarxToken([string] $tokenUrl, [int] $tokenLifetimeInSeconds, 
	[string] $checkmarxUsername, [string] $checkmarxPwd, 
	[Token] $previousToken) {

	$token = $previousToken
	if ($null -ne $token -and $token.isValid()) {
		return $token
	}

	$tokenResponse = New-CheckmarxToken $tokenUrl $checkmarxUsername $checkmarxPwd
	return new-object Token($tokenResponse.access_token, $tokenLifetimeInSeconds)
}

write-verbose "Reading scan request file ($scanRequestFilePath)..."
$scanRequestConfig = Get-Config $scanRequestFilePath

$workDirectory = $scanRequestConfig.request.workdirectory
write-verbose "Using work directory $workDirectory"

$checkmarxProjectId = $scanRequestConfig.checkmarx.projectId
if ($checkmarxProjectId -eq 0) {
	throw 'A project ID of 0 indicates an incomplete Checkmarx configuration'
}

$checkmarxUsername = Get-FileContents (join-path $workDirectory 'workflow-secrets/checkmarx-project-credential/username')
$checkmarxPassword = Get-FileContents (join-path $workDirectory 'workflow-secrets/checkmarx-project-credential/password')

Set-Tlsv12

$checkmarxBaseUrl = $scanRequestConfig.checkmarx.baseurl
$tokenUrl = "$checkmarxBaseUrl/cxrestapi/auth/identity/connect/token"

$tokenLifetimeInSeconds = 3000
if ($null -ne $scanRequestConfig.checkmarx.tokenLifetimeInSeconds) {
	$tokenLifetimeInSeconds = $scanRequestConfig.checkmarx.tokenLifetimeInSeconds
}
write-verbose "Using tokenLifetimeInSeconds $tokenLifetimeInSeconds"

$token = $null
$authorizationHeader = {
	$script:token = Get-CheckmarxToken $tokenUrl $tokenLifetimeInSeconds $checkmarxUsername $checkmarxPassword $script:token
	@{
		'Authorization' = "Bearer $($script:token.accessToken)"
	}
}

$inputDirectory = join-path $scanRequestConfig.request.workdirectory 'input'
$sourcePath = (Get-ChildItem $inputDirectory | Select-Object -First 1).FullName

write-verbose "Step: Uploading source $sourcePath..."
$form = @{zippedSource=(Get-ChildItem $sourcePath)}
Invoke-RestMethod "$checkmarxBaseUrl/cxrestapi/projects/$checkmarxProjectId/sourceCode/attachments" -Method Post -Form $form -Headers (& $authorizationHeader)

write-verbose 'Step: Starting scan...'
$startScanUrl = "$checkmarxBaseUrl/cxrestapi/sast/scans"

$isIncremental = 'false'
if ($null -ne $scanRequestConfig.scan.isIncremental) {
	$isIncremental = $scanRequestConfig.scan.isIncremental.tostring().tolower()
}
write-verbose "Using isIncremental $isIncremental"

$startScanBody = @{
	'projectId' = "$checkmarxProjectId"
	'isIncremental' = $isIncremental
	'isPublic' = 'true'
	'forceScan' = 'true'
	'comment' = "$checkmarxProjectId"
}

$startScanResponse = Invoke-RestMethod -Uri $startScanUrl `
	-Method Post `
	-Body (ConvertTo-Json $startScanBody) `
	-Header (& $authorizationHeader) `
	-ContentType 'application/json'

$scanId = $startScanResponse.id

$waitForCompletionSleepTimeInSeconds = $scanRequestConfig.scan.checkscanstatusdelay
write-verbose "Step: Wait for scan to complete (using check-status delay $($waitForCompletionSleepTimeInSeconds))..."

$waitForScanUrl = "$checkmarxBaseUrl/cxrestapi/sast/scans/$scanId"
$waitForScanResponse = Invoke-RestMethod -Uri $waitForScanUrl `
	-Method Get `
	-Header (& $authorizationHeader)

while ($waitForScanResponse.status.name -ne 'Finished') {
	write-verbose "  Waiting for scan completion..."
	Start-Sleep -seconds $waitForCompletionSleepTimeInSeconds
	$waitForScanResponse = Invoke-RestMethod -Uri $waitForScanUrl `
		-Method Get `
		-Header (& $authorizationHeader)
}

write-verbose 'Step: Creating new XML report...'
$createReportUrl = "$checkmarxBaseUrl/cxrestapi/reports/sastScan"

$createReportBody = @{
	'reportType' = 'XML'
	'scanId' = "$scanId"
}

$createReportResponse = Invoke-RestMethod -Uri $createReportUrl `
	-Method Post `
	-Header (& $authorizationHeader) `
	-Body $createReportBody

$reportId = $createReportResponse.reportId

write-verbose 'Step: Waiting for report to complete...'
$getReportStatusUrl = "$checkmarxBaseUrl/cxrestapi/reports/sastScan/$reportId/status"

$getReportStatusResponse = Invoke-RestMethod -Uri $getReportStatusUrl `
	-Method Get `
	-Header (& $authorizationHeader)

while ($getReportStatusResponse.status.value -ne 'Created') {
	write-verbose "  Waiting for report completion..."
	Start-Sleep -seconds $waitForCompletionSleepTimeInSeconds
	$getReportStatusResponse = Invoke-RestMethod -Uri $getReportStatusUrl `
		-Method Get `
		-Header (& $authorizationHeader)
}

write-verbose 'Step: Fetching XML report...'
$fetchReportUrl = "$checkmarxBaseUrl/cxrestapi/reports/sastScan/$reportId"

$fetchReportResponse = Invoke-RestMethod -Uri $fetchReportUrl `
	-Method Get `
	-Header (& $authorizationHeader)

$reportOutputPath = $scanRequestConfig.request.resultfilepath
write-verbose "Saving report to $reportOutputPath..."

# Due to 'Invoke-RestMethod' possibly converting a string response into a more representative data type, and we want to work with a String,
# convert XML back to String
if ($fetchReportResponse -is [xml]) {
	[string] $fetchReportStrResponse = $fetchReportResponse.OuterXml
}

$reportStart = $fetchReportStrResponse.IndexOf('<?xml ')

[io.file]::WriteAllText($reportOutputPath, $fetchReportStrResponse.Substring($reportStart))
