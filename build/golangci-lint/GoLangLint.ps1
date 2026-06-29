#
# This script takes the following steps to obtain a report from a golangci-lint linter.
#
# Step 1: Unpack source code
# Step 2) Change to root build directory or an alternate subdirectory
# Step 3) Run a golangci-lint linter that SRM supports
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

$linter  = $scanRequestConfig.linter
$options = $scanRequestConfig.options

write-verbose @"
linter:  $linter
options: $options
"@

write-verbose 'Step 1: Unpacking source code...'
$sourceDir = New-Item -ItemType Directory -Path (Join-Path ([io.path]::GetTempPath()) (split-path $sourcePath -Leaf))
Expand-SourceArchive $sourcePath $sourceDir -restoreGitDirectory

$sourceCode = $scanRequestConfig.'source-code'
$sourceDir = Push-BaseSourceCodeDirectory $sourceDir $sourceCode.relativeDirectory $sourceCode.projectFileDirectoryPatterns

write-verbose "Validating linter $linter..."
if ([string]::IsNullOrWhiteSpace($linter)) {
	Exit-Script 'No linter specified'
}

$linters = @{
	'errcheck' = @{
		header = 'ErrCheck'
	}
	# revive is a drop-in replacement for GoLint
	'revive' = @{
		header = 'GoLint'
	}
	'golint' = @{
		header = 'GoLint'
	}
	'ineffassign' = @{
		header = 'IneffAssign'
	}
}
if ($linters.Keys -notcontains $linter) {
	Exit-Script "SRM does not support linter $linter."
}
if ($linters.options -contains '--timeout') {
	Exit-Script 'The golangci-lint options cannot include --timeout'
}

write-verbose 'Validating options...'
$invalidOptionRegex = (
	'out-format',
	'output\.text\.print-issued-lines',
	'output\.text\.print-linter-name',
	'print-issued-lines',
	'print-linter-name',
	'issues-exit-code',
	'disable-all',
	'default'
) -join '|'

$invalidOptions = $options -match "^\s*--($invalidOptionRegex)(?:=.+)?$"
write-verbose "Matches: $matches"

if ($invalidOptions.count -gt 0) {
	Exit-Script  "The following options conflict with options set by SRM: $invalidOptions"
}

write-verbose "Step 3: Running $linter..."

golangci-lint --version

write-output "##tool = $($linters[$linter].header)" | out-file -LiteralPath $outputPath -Append
golangci-lint run @($options) --output.text.print-issued-lines=false --output.text.print-linter-name=false --issues-exit-code=0 --default=none -E $linter $scanRequestConfig.packages | out-file -LiteralPath $outputPath -Append
if ($LASTEXITCODE -ne 0) {
	Exit-Script "Unexpected exit code from golangci-lint ($LASTEXITCODE)."
}
write-verbose 'Done'
