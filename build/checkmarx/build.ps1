param (
	[string] $imageVersion='v1.0',
	[string] $registry='',
	[string] $username='',
	[Parameter(ValueFromPipeline=$true)][string] $pwd=''
)

$ErrorActionPreference = 'Stop'
Set-PSDebug -Strict

Push-Location $PSScriptRoot

. ..\common\docker.ps1
. ..\common\common.ps1

Invoke-ImageBuild '../..' (get-item './Dockerfile').fullname '' "codedx-checkmarxrunner:$imageVersion" $registry $username $pwd
