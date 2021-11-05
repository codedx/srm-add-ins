#
# This script takes the following steps to obtain a report from staticcheck.
#
# Step 1: Unpack source code
# Step 2) Change to root build directory or an alternate subdirectory
# Step 3) Run staticcheck
#
#

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

$options = $scanRequestConfig.options

write-verbose @"
options: $options
"@

write-verbose 'Step 1: Unpacking source code...'
$sourceDir = New-Item -ItemType Directory -Path (Join-Path ([io.path]::GetTempPath()) (split-path $sourcePath -Leaf))
Expand-SourceArchive $sourcePath $sourceDir -restoreGitDirectory

$sourceCode = $scanRequestConfig.'source-code'
$sourceDir = Push-BaseSourceCodeDirectory $sourceDir $sourceCode.relativeDirectory $sourceCode.projectFileDirectoryPatterns

write-verbose 'Validating options...'
$invalidOptionRegex = 'f'

$invalidOptions = $options -match "^\s*-($invalidOptionRegex)(?:=.+)?$"
write-verbose "Matches: $matches"

if ($invalidOptions) {
	Exit-Script  "The following options conflict with options set by Code Dx: $invalidOptions"
}

write-verbose 'Step 3: Running staticcheck...'

staticcheck -version

write-output '##tool = Staticcheck'   | out-file -LiteralPath $outputPath -Append
$beforeSize = (get-item $outputPath).length

staticcheck @($options) -f json $scanRequestConfig.packages | out-file -LiteralPath $outputPath -Append
if ($LASTEXITCODE -ne 0) {
	$afterSize = (get-item $outputPath).length
	if ($beforeSize -eq $afterSize) { # staticheck will return non-zero when items are found
		Exit-Script "Unexpected exit code from staticcheck ($LASTEXITCODE)."
	}
}
write-verbose 'Done'
