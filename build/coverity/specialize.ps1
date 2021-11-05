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
$version = Get-ChildItem -Filter 'cov-analysis-linux64-*.tar.gz' -File | 
	Select-Object -First 1 | 
	ForEach-Object { $_.Name -Match 'cov-analysis-linux64-(?<version>.+)\.tar\.gz' | Out-Null; $matches.version }

if ($null -eq $version) {
	Write-Verbose 'Skipping specialization of Coverity Docker image because a Coverity software package cannot be found'
	exit 0
}

if (-not (Test-Path 'license.dat' -PathType Leaf)) {
	Write-Verbose 'Skipping specialization of Coverity Docker image because a Coverity license file cannot be found'
	exit 0
}

$dockerfilePrefix = @"
ARG BASE=$baseImageName
ARG VERSION=2021.06

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

COPY --chown=coverity:coverity --from=builder /tmp/coverity /opt/sw/synopsys/coverity
COPY --chown=coverity:coverity license.dat /opt/sw/synopsys/coverity/bin
'@

$dockerfile = 'Dockerfile-specialized'
$dockerfilePrefix + $dockerfileContext  | Out-File $dockerfile -Encoding ASCII -Force

Invoke-ImageBuild '.' (get-item $dockerfile).fullname '' $imageName $registry $username $pwd
