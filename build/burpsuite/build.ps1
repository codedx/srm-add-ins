#
# This script will build the codedx-burpsuiterunnerbase Docker image, which contains components
# to automate Burp Suite using a PowerShell script and a Burp Suite Extender. If the script
# finds a file matching the name pattern burpsuite*.jar, it will generate a second Docker image
# named codedx-burpsuiterunner-unactivated with the Burp Suite jar stored in the 
# /opt/codedx/burpsuite/bin directory.
#
# The codedx-burpsuiterunner-unactivated Docker image runs as the burpsuite user, but it doesn't
# have a licensed and activated copy of Burp Suite.
#
# To create a new Docker image named codedx-burpsuiterunner-licensed that's derived from
# codedx-burpsuiterunner-unactivated, do the following:
#
# 1) Run a new shell in the codedx-burpsuiterunner-unactivated:v1.0 container:
#    docker run -it --name burpsuite codedx-burpsuiterunner-unactivated:v1.0 sh
#
# 2) From the container, run Burp and activate your license (replace burpsuite_pro.jar if necessary):
#    a. java -jar /opt/codedx/burpsuite/bin/burpsuite_pro.jar
#    b. Respond to license agreement question
#    c. Paste license text
#    d. Enter activation method
#    e. Enter Ctrl+C to exit BurpSuite and leave the container running
#
# 3) From another terminal window, save your changes as a new Docker image:
#    docker commit burpsuite codedx-burpsuiterunner-licensed:v1.0
#
# 4) Click Add-In Tools on the Code Dx Admin page and edit the TOML configuration:
#    a. Set the imageName parameter by referencing your licensed Burp Suite Docker image name
#    b. Under shellCmd, set the burpsuite_pro.jar filename of parameter two to match the filename from 2a.
#
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

$baseImageName = "codedx-burpsuiterunnerbase:$imageVersion"
Invoke-ImageBuild '../..' (get-item './Dockerfile').fullname '' $baseImageName $registry $username $pwd

$burpSuiteJar = get-item .\burpsuite*.jar | select-object -first 1
if ($null -eq $burpSuiteJar) {
	Write-Verbose "Skipping derived Burp Suite image after building Burp Suite base image (Burp Suite software not found)"
	exit 0
}

$burpSuiteDockerfileName = 'Dockerfile-BurpSuite'
$tempFolder = New-Item (Join-Path ([io.path]::GetTempPath()) ([guid]::NewGuid())) -Type Container
$dockerfile = Join-Path $tempFolder $burpSuiteDockerfileName

@"
FROM $baseImageName
COPY $($burpSuiteJar.name) /opt/codedx/burpsuite/bin/$($burpSuiteJar.name)
"@ | Out-File $dockerfile -Encoding ASCII -Force

Copy-Item ($burpSuiteJar.name) $tempFolder
Invoke-ImageBuild $tempFolder $dockerfile '' "codedx-burpsuiterunner-unactivated:$imageVersion" $registry $username $pwd



