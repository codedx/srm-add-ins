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

$baseDockerImageName = "codedx-coverityrunnerbase-sbt-java11:$imageVersion"
Invoke-ImageBuild '../..' (get-item './Dockerfile').fullname '' $baseDockerImageName $registry $username $pwd

. ../coverity/specialize.ps1 '../coverity' $baseDockerImageName "codedx-coverityrunnerbase-sbt-java11:$imageVersion" $registry $username $pwd
