
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

	Invoke-RestMethod -Uri "$baseUrl/api/analysis-prep" -Method 'POST' -Headers $headers -Body $body
}

function Get-AnalysisPrep([string] $baseUrl, [string] $apiKey, [string] $analysisPrepId) {

	$headers = New-Header $apiKey
	$headers['accept'] = 'application/json'

	Invoke-RestMethod -Uri "$baseUrl/api/analysis-prep/$analysisPrepId" -Headers $headers
}

function Get-InputMetadata([string] $baseUrl, [string] $apiKey, [string] $analysisPrepId, [string] $inputId) {

	$headers = New-Header $apiKey
	Invoke-RestMethod -Uri "$baseUrl/api/analysis-prep/$analysisPrepId/$inputId" -Headers $headers
}

function Set-DynamicToolDisabled([string] $baseUrl, [string] $apiKey, [string] $analysisPrepId, [string] $toolId) {

	$headers = New-Header $apiKey
	Invoke-RestMethod -Uri "$baseUrl/x/analysis-prep/$analysisPrepId/addin/$toolId" -Method 'DELETE' -Headers $headers
}

function Set-ToolConnectorDisabled([string] $baseUrl, [string] $apiKey, [string] $analysisPrepId, [string] $connectorId) {

	$headers = New-Header $apiKey
	Invoke-RestMethod -Uri "$baseUrl/x/analysis-prep/$analysisPrepId/connector/$connectorId" -Method 'DELETE' -Headers $headers
}

function Set-ToolInputDisabled([string] $baseUrl, [string] $apiKey, [string] $analysisPrepId, [string] $inputId, [string] $tagId) {

	$headers = New-Header $apiKey

	$body = ConvertTo-Json @{ 'enabled' = $false }

	Invoke-RestMethod -Uri "$baseUrl/api/analysis-prep/$analysisPrepId/$inputId/tag/$tagId" -Method 'PUT' -Headers $headers -Body $body
}

function Add-InputFile([string] $baseUrl, [string] $apiKey, [string] $analysisPrepId, [string] $filePath) {

	$fileItem = Get-ChildItem $filePath
	$form = @{uploadFile=$fileItem}

	Write-Verbose "File upload of '$fileItem' (size $($fileItem.length)) starting at $([datetime]::UtcNow) (UTC)..."
	Try {
		Invoke-RestMethod `
		-TimeoutSec 0 `
		-Headers (New-Header $apiKey) `
		-Method Post `
		-Form $form `
		-ContentType 'multipart/form-data' `
		-Uri "$baseUrl/api/analysis-prep/$analysisPrepId/upload"
	} Finally {
		Write-Verbose "File upload of '$fileItem' ended at $([datetime]::UtcNow) (UTC)..."
	}
}

function Invoke-Analyze([string] $baseUrl, [string] $apiKey, [string] $analysisPrepId) {

	$headers = New-Header $apiKey
	$headers['accept'] = 'application/json'

	Invoke-RestMethod -Uri "$baseUrl/api/analysis-prep/$analysisPrepId/analyze" -Method POST -Headers $headers
}

function Wait-CodeDxJob([string] $baseUrl, [string] $apiKey, [string] $jobId, [int] $waitDuration) {

	$headers = New-Header $apiKey
	$headers['accept']       = 'application/json'

	$timeout = [datetime]::MaxValue
	if ($waitDuration -gt 0) {
		$timeout = [datetime]::Now.AddSeconds($waitDuration)
	}

	do {
		$status = Invoke-RestMethod -Uri "$baseUrl/api/jobs/$jobId" -Headers $headers
		
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
