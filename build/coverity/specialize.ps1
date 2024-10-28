param (
	[Parameter(Mandatory=$true)][string] $coveritySoftwareDirectory,
	[Parameter(Mandatory=$true)][string] $baseImageName,
	[Parameter(Mandatory=$true)][string] $imageName,
	[string] $registry='',
	[string] $username='',
	[Parameter(ValueFromPipeline=$true)][string] $pwd=''
)

$ErrorActionPreference = 'Stop'
Set-PSDebug -Strict

Push-Location $PSScriptRoot
. ..\common\docker.ps1
. ..\common\common.ps1

Push-Location $coveritySoftwareDirectory

# Extract Coverity version from Coverity tar file, which should be alongside this file
$coveritySoftwareArchive = Get-ChildItem -Filter 'cov-analysis-linux64-*.tar.gz' -File
$version = $coveritySoftwareArchive | 
	Select-Object -First 1 | 
	ForEach-Object { $_.Name -Match 'cov-analysis-linux64-(?<version>.+)\.tar\.gz' | Out-Null; $matches.version }

if ($null -eq $version) {
	Write-Verbose 'Skipping specialization of Coverity Docker image because a Coverity software package cannot be found'
	exit 0
}

$licenseFile = 'license.dat'
if (-not (Test-Path $licenseFile -PathType Leaf)) {
	Write-Verbose 'Skipping specialization of Coverity Docker image because a Coverity license file cannot be found'
	exit 0
}

$workDirectory = join-path ([io.path]::GetTempPath()) ([guid]::NewGuid())

Write-Verbose "Creating directory $workDirectory..."
$workDirectoryItem = New-Item -Path $workDirectory -ItemType Directory

Write-Verbose "Copying Coverity software files..."
Copy-Item $coveritySoftwareArchive $workDirectory
Copy-Item $licenseFile $workDirectory
Pop-Location

Write-Verbose "Creating Dockerfile..."
Push-Location $workDirectory

$dockerfilePrefix = @"
ARG BASE=$baseImageName
ARG VERSION=2023.09

ARG ANALYSIS_ARCHIVE=cov-analysis-linux64-$version.tar.gz

"@

$dockerfileContext = @'
FROM $BASE as builder
ARG  ANALYSIS_ARCHIVE
USER root

WORKDIR /tmp
COPY $ANALYSIS_ARCHIVE .

WORKDIR /tmp/coverity
RUN tar xvf /tmp/${ANALYSIS_ARCHIVE} --strip-components=1

FROM $BASE
ARG  VERSION

ENV VERSION=$VERSION \
	PLATFORM=linux64

COPY --chown=coverity:coverity --from=builder /tmp/coverity /opt/sw/blackduck/coverity
COPY --chown=coverity:coverity license.dat /opt/sw/blackduck/coverity/bin
'@

$dockerfile = 'Dockerfile-specialized'
$dockerfilePrefix + $dockerfileContext  | Out-File $dockerfile -Encoding ASCII -Force

Invoke-ImageBuild '.' (get-item $dockerfile).fullname '' $imageName $registry $username $pwd

Write-Verbose "Removing temporary work directory..."
Pop-Location
$workDirectoryItem.Delete($true)
