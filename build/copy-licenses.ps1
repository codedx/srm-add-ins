$ErrorActionPreference = 'Stop'
Set-PSDebug -Strict

Push-Location $PSScriptRoot

. .\common\licenses.ps1

Invoke-GatherLicenseFiles ..\cmd\testconnect  .\licenses
Invoke-GatherLicenseFiles ..\cmd\zap          .\licenses

