$VerbosePreference = 'Continue'
$ErrorActionPreference = 'Stop'
Set-PSDebug -Strict

function New-Header([string] $apiKey) {
	@{ 'API-Key' = $apiKey }
}

function New-AnalysisPrep([string] $baseUrl, [string] $apiKey, [int] $projectId) {

	$headers = New-Header $apiKey
	$headers['Content-Type'] = 'application/json'
	$headers['accept']       = 'application/json'

	$body = ConvertTo-Json @{ 'projectId' = $projectId }

	Invoke-RestMethod -Uri "$codeDxBaseUrl/api/analysis-prep" -Method 'POST' -Headers $headers -Body $body
}

function Get-AnalysisPrep([string] $baseUrl, [string] $apiKey, [string] $analysisPrepId) {

	$headers = New-Header $apiKey
	$headers['accept'] = 'application/json'

	Invoke-RestMethod -Uri "$codeDxBaseUrl/api/analysis-prep/$analysisPrepId" -Headers $headers
}

function Get-InputMetadata([string] $baseUrl, [string] $apiKey, [string] $analysisPrepId, [string] $inputId) {

	$headers = New-Header $apiKey
	Invoke-RestMethod -Uri "$codeDxBaseUrl/api/analysis-prep/$analysisPrepId/$inputId" -Headers $headers
}

function Set-DynamicToolDisabled([string] $baseUrl, [string] $apiKey, [string] $analysisPrepId, [string] $toolId) {

	$headers = New-Header $apiKey
	Invoke-RestMethod -Uri "$codeDxBaseUrl/x/analysis-prep/$analysisPrepId/addin/$toolId" -Method 'DELETE' -Headers $headers
}

function Set-ToolConnectorDisabled([string] $baseUrl, [string] $apiKey, [string] $analysisPrepId, [string] $connectorId) {

	$headers = New-Header $apiKey
	Invoke-RestMethod -Uri "$codeDxBaseUrl/x/analysis-prep/$analysisPrepId/connector/$connectorId" -Method 'DELETE' -Headers $headers
}

function Set-ToolInputDisabled([string] $baseUrl, [string] $apiKey, [string] $analysisPrepId, [string] $inputId, [string] $tagId) {

	$headers = New-Header $apiKey

	$body = ConvertTo-Json @{ 'enabled' = $false }

	Invoke-RestMethod -Uri "$codeDxBaseUrl/api/analysis-prep/$analysisPrepId/$inputId/tag/$tagId" -Method 'PUT' -Headers $headers -Body $body
}

function Add-InputFile([string] $baseUrl, [string] $apiKey, [string] $analysisPrepId, [string] $filePath) {

	$curlCmd = (get-command curl -Type application -erroraction silentlycontinue).source | select-object -first 1
	if ($null -eq $curlCmd) {
		throw 'Unable to find the curl application required for upload'
	}

	$result = & $curlCmd -X POST "$codeDxBaseUrl/api/analysis-prep/$analysisPrepId/upload" -H "API-Key: $apiKey" -H "Content-Type: multipart/form-data" -F "file=@$filePath"
	ConvertFrom-Json $result
}

function Invoke-Analyze([string] $baseUrl, [string] $apiKey, [string] $analysisPrepId) {

	$headers = New-Header $apiKey
	$headers['accept'] = 'application/json'

	Invoke-RestMethod -Uri "$codeDxBaseUrl/api/analysis-prep/$analysisPrepId/analyze" -Method POST -Headers $headers
}

function Wait-CodeDxJob([string] $baseUrl, [string] $apiKey, [string] $jobId, [int] $waitDuration) {

	$headers = New-Header $apiKey
	$headers['accept']       = 'application/json'

	$timeout = [datetime]::MaxValue
	if ($waitDuration -gt 0) {
		$timeout = [datetime]::Now.AddSeconds($waitDuration)
	}

	do {
		$status = Invoke-RestMethod -Uri "$codeDxBaseUrl/api/jobs/$jobId" -Headers $headers
		
		$doneStatus = 'completed','failed','cancelled'
		if ($doneStatus -contains $status.status) {
			return $status.status
		}

		if ([datetime]::now -ge $timeout) {
			throw "Timeout occurred while waiting on job $jobId"
		}

		$sleepDurationSeconds = 5
		Write-Verbose "Job $jobId is not yet complete with status $($status.status); sleeping for $sleepDurationSeconds seconds (timeout at $timeout)..."
		Start-Sleep -Seconds $sleepDurationSeconds

	} while ($true)
}
