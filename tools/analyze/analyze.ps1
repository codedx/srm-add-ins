param (
	[string]                                     $codeDxBaseUrl,
	[string]                                     $codeDxApiKey,
	[Parameter(Mandatory=$true)][int]            $projectId,
	[Parameter(Mandatory=$true)][string]         $inputFilePath,
	[System.Collections.Generic.HashSet[string]] $dynamicToolsAllowed   = [Collections.Generic.HashSet[string]]::new(),
	[System.Collections.Generic.HashSet[string]] $toolInputsAllowed     = [Collections.Generic.HashSet[string]]::new(),
	[System.Collections.Generic.HashSet[string]] $toolConnectorsAllowed = [Collections.Generic.HashSet[string]]::new(),
	[int]                                        $jobWaitDuration       = 15*60,
	[switch]                                     $waitForAnalysis
)
$VerbosePreference = 'Continue'

. (join-path $PSScriptRoot 'codedx.ps1')

if ($codeDxBaseUrl -eq '') {
	$codeDxBaseUrl = $Env:CODE_DX_BASE_URL
}

if ($codeDxApiKey -eq '') {
	$codeDxApiKey = $Env:CODE_DX_API_KEY
}

if ($null -eq $dynamicToolsAllowed) {
	$dynamicToolsAllowed = [Collections.Generic.HashSet[string]]::new()
}

if ($null -eq $toolInputsAllowed) {
	$toolInputsAllowed = [Collections.Generic.HashSet[string]]::new()
}

if ($null -eq $toolConnectorsAllowed) {
	$toolConnectorsAllowed = [Collections.Generic.HashSet[string]]::new()
}

if ($codeDxBaseUrl.EndsWith('/')) {
	$codeDxBaseUrl = $codeDxBaseUrl.Substring(0, $codeDxBaseUrl.Length - 1)
}

Write-Verbose "Creating analysis prep at $codeDxBaseUrl for project $projectId..."
$analysisPrep   = New-AnalysisPrep $codeDxBaseUrl $codeDxApiKey $projectId
$analysisPrepId = $analysisPrep.prepId

Write-Verbose 'Searching for enabled dynamic tools...'
$analysisPrep.dynamicTools | Where-Object { 
	$_.enabled -and
	-not $dynamicToolsAllowed.Contains($_.toolInput)
} | ForEach-Object {

	Write-Verbose "Disabling dynamic tool '$($_.toolInput)' with ID $($_.id)..."
	Set-DynamicToolDisabled $codeDxBaseUrl $codeDxApiKey $analysisPrepId $_.id
}

Write-Verbose 'Searching for enabled tool connectors...'
$analysisPrep.toolConnectors | Where-Object { 
	$_.enabled -and
	-not $toolConnectorsAllowed.Contains($_.toolInput)
} | ForEach-Object {

	Write-Verbose "Disabling tool connector '$($_.toolInput)' with ID $($_.id)..."
	Set-ToolConnectorDisabled $codeDxBaseUrl $codeDxApiKey $analysisPrepId $_.id
}

Write-Verbose "Uploading input file $inputFilePath..."
$result = Add-InputFile $codeDxBaseUrl $codeDxApiKey $analysisPrepId $inputFilePath

Write-Verbose "Waiting for job $($result.jobId) (timeout is $jobWaitDuration seconds)..."
$jobStatus = Wait-CodeDxJob $codeDxBaseUrl $codeDxApiKey $result.jobId $jobWaitDuration

$completedStatus = 'completed'
if ($jobStatus -ne $completedStatus) {
	throw "Upload job unexpectedly failed with job status $jobStatus"
}

Write-Verbose "Fetching analysis prep $analysisPrepId..."
$analysisPrep = Get-AnalysisPrep $codeDxBaseUrl $codeDxApiKey $analysisPrepId

Write-Verbose "Fetching input metadata from prep $analysisPrepId for input $($analysisPrep.inputIds[0])..."
$inputMetadata = Get-InputMetadata $codeDxBaseUrl $codeDxApiKey $analysisPrepId $analysisPrep.inputIds[0]

Write-Verbose 'Searching for enabled tool inputs...'
$inputMetadata.tags | Where-Object { 
	$null -ne $_.toolInput -and
	$_.enabled -and
	-not $toolInputsAllowed.Contains($_.toolInput)
} | ForEach-Object {

	Write-Verbose "Disabling tool input '$($_.toolInput)' with ID $($_.id)..."
	Set-ToolInputDisabled $codeDxBaseUrl $codeDxApiKey $analysisPrepId $analysisPrep.inputIds[0] $_.id
}

Write-Verbose 'Invoking analysis...'
$analysis = Invoke-Analyze $codeDxBaseUrl $codeDxApiKey $analysisPrepId

if ($waitForAnalysis) {

	Write-Verbose 'Waiting on analysis...'
	$jobStatus = Wait-CodeDxJob $codeDxBaseUrl $codeDxApiKey $analysis.jobId $jobWaitDuration

	if ($jobStatus -ne $completedStatus) {
		throw "Analysis job unexpectedly failed with job status $jobStatus"
	}
}