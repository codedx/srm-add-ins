#
# This script takes the following steps to obtain a report from a Coverity scanner.
#
# Step 1: Unpack source code
# Step 2) Change to root build directory or an alternate subdirectory
# Step 3) Run cov-build/cov-capture
# Step 4) Run cov-analyze with specified command arguments
# Step 5) Run cov-format-errors

param (
	[Parameter(Mandatory=$true)][string] $sourcePath,
	[Parameter(Mandatory=$true)][string] $scanRequestFilePath,
	[string] $intermediateDirectory
)

Set-PSDebug -Strict
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

. ./add-in.ps1

'cov-configure','cov-build','cov-capture','cov-analyze','cov-format-errors' | ForEach-Object {
	$command = Get-Command $_ -Type Application -ErrorAction SilentlyContinue
	if ($null -eq $command) {
		Exit-Script "Unable to find Coverity command $_. Does your Docker image include a licensed Coverity version? Refer to this script for details on how to build your own Docker image: https://github.com/codedx/codedx-add-ins/blob/main/build/coverity/specialize.ps1"
	}
}

if ($intermediateDirectory -eq '') {
	$intermediateDirectory = join-path (split-path $PSScriptRoot) 'idir'
}

write-verbose "Reading scan request file ($scanRequestFilePath)..."
$scanRequestConfig = Get-Config $scanRequestFilePath

write-verbose 'Running cov-configure...'
$scanRequestConfig.'cov-configure'.options | ForEach-Object {

	write-verbose "cov-configure $_"
	cov-configure $_
	if ($LASTEXITCODE -ne 0) {
		Exit-Script "Failed to run cov-configure ($LASTEXITCODE)"
	}
}

write-verbose "Step 1: Unpacking source code..."
$sourceDir = New-Item -ItemType Directory -Path (Join-Path ([io.path]::GetTempPath()) (split-path $sourcePath -Leaf))
Expand-SourceArchive $sourcePath $sourceDir -restoreGitDirectory

$sourceCode = $scanRequestConfig.'source-code'
$sourceDir = Push-BaseSourceCodeDirectory $sourceDir $sourceCode.relativeDirectory $sourceCode.projectFileDirectoryPatterns

$allowedEnvironmentVariables = @('$Env:CodeDxAddInSourceDir')

$buildCmdLine = $scanRequestConfig.'cov-build'.buildCmdLine
if ($buildCmdLine.length -gt 0) {

	write-verbose 'Step 3: Running cov-build with specified command arguments...'

	$preBuildCmdLine = $scanRequestConfig.'cov-build'.preBuildCmdLine
	if (-not ([string]::IsNullOrWhitespace($preBuildCmdLine))) {
		write-verbose "Running prebuild command $preBuildCmdLine..."
		Invoke-Expression -Command $preBuildCmdLine
	}

	$covBuildOptions = Set-OptionsEnvironmentVariables $scanRequestConfig.'cov-build'.options $allowedEnvironmentVariables
	cov-build --dir $intermediateDirectory @($covBuildOptions) @($buildCmdLine)
	if ($LASTEXITCODE -ne 0) {
		Exit-Script "Failed to run cov-build at '$sourceDir' with build command line '$buildCmdLine' ($LASTEXITCODE)"
	}
} else {

	write-verbose 'Step 3: Running cov-capture with specified command arguments...'
	$covCaptureOptions = Set-OptionsEnvironmentVariables $scanRequestConfig.'cov-capture'.options $allowedEnvironmentVariables
	cov-capture --dir $intermediateDirectory --project-dir $sourceDir @($covCaptureOptions)
	if ($LASTEXITCODE -ne 0) {
		Exit-Script "Failed to run cov-capture at '$sourceDir' with build command line '$buildCmdLine' ($LASTEXITCODE)"
	}
}

write-verbose 'Step 4: Running cov-analyze with specified command arguments...'
$covAnalyzeOptions = Set-OptionsEnvironmentVariables $scanRequestConfig.'cov-analyze'.options $allowedEnvironmentVariables
cov-analyze --dir $intermediateDirectory @($covAnalyzeOptions)
if ($LASTEXITCODE -ne 0) {
	Exit-Script "Failed to run cov-analyze at '$sourceDir' ($LASTEXITCODE)"
}

write-verbose 'Step 5: Running cov-format-errors...'
$outputPath = $scanRequestConfig.request.resultfilepath
cov-format-errors --dir $intermediateDirectory --json-output-v8 $outputPath

write-verbose 'Done'
