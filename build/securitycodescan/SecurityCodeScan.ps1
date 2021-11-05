#
# This script takes the following steps to obtain a report from a Security Code Scan scanner.
#
# Step 1: Unpack source code
# Step 2) Change to build directory
# Step 3) Add SecurityCodeScan.VS2017 to projects
# Step 4) Run dotnet build

param (
	[Parameter(Mandatory=$true)][string] $sourcePath,
	[Parameter(Mandatory=$true)][string] $outputPath,
	[Parameter(Mandatory=$true)][string] $scanRequestFilePath
)

Set-PSDebug -Strict
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

. ./add-in.ps1

write-verbose "Reading scan request file ($scanRequestFilePath)..."
$scanRequestConfig = Get-Config $scanRequestFilePath

write-verbose "Step 1: Unpack source code..."
$sourceDir = New-Item -ItemType Directory -Path (Join-Path ([io.path]::GetTempPath()) (split-path $sourcePath -Leaf))
Expand-SourceArchive $sourcePath $sourceDir -restoreGitDirectory

write-verbose "Step 2: Locating build point..."

$relativeDirectory = $scanRequestConfig.build.relativeDirectory
$projectFileDirectoryPatterns = '*.sln','*.csproj','*.vbproj','*.fsproj'

$sourceCode = $scanRequestConfig.'source-code' # legacy TOML file does not include this property
if ($null -ne $sourceCode) {
	write-verbose 'Using source-code TOML format...'
	$relativeDirectory = $sourceCode.relativeDirectory
	$projectFileDirectoryPatterns = $sourceCode.projectFileDirectoryPatterns
}
$sourceDir = Push-BaseSourceCodeDirectory $sourceDir $relativeDirectory $projectFileDirectoryPatterns

write-verbose "Step 3: Add SecurityCodeScan.VS2017 package to projects..."
$projectFiles = Get-ChildItem -include '*.csproj','*.vbproj','*.fsproj' -recurse
$projectFiles | foreach-object {
	$projectPath = $_.FullName
	dotnet add $projectPath package SecurityCodeScan.VS2017
	if ($LASTEXITCODE -ne 0) {
		Exit-Script "Failed to add Security Code Scan to project $projectPath ($LASTEXITCODE)"
	}
}

write-verbose "Step 4: Run dotnet build from $sourceDir..."
dotnet build | tee-object $outputPath
if ($LASTEXITCODE -ne 0) {
	Exit-Script "Failed to build source code: $LASTEXITCODE"
}

write-verbose 'Done'
