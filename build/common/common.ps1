$ErrorActionPreference = 'Stop'
Set-PSDebug -Strict

function Invoke-FileCopy([Parameter(Mandatory=$true)][io.fileinfo] $file,
	[Parameter(Mandatory=$true)][io.directoryinfo] $directory) {

	if (-not $file.Exists) {
		throw "Unable to find file $file"
	}

	if (-not $directory.Exists) {
		throw "Unable to find directory $directory"
	}

	if ($file.Directory.FullName -ne $directory.FullName) {
		copy $file $directory
	}
}

function Invoke-ImageBuild(
	[Parameter(Mandatory=$true)][string] $rootPath,
	[Parameter(Mandatory=$true)][string] $dockerfilePath,
	[string] $dockerfileIgnorePath,
	[Parameter(Mandatory=$true)][string] $dockerImageName,
	[string] $registry,
	[string] $username,
	[string] $password) {

	if (-not [string]::IsNullOrWhiteSpace($dockerfileIgnorePath)) {
		Invoke-FileCopy $dockerfileIgnorePath $rootPath
	}

	pushd $rootPath
	try {

		Invoke-DockerBuild $dockerImageName $dockerfilePath

		if ($registry -ne '') {

			Invoke-DockerLogin $registry $username $password

			$dockerImageTagName = "$registry/codedx/$dockerImageName"
			Invoke-DockerPush $dockerImageName $dockerImageTagName -skipLatestTag

			Invoke-DockerRemoveImage $dockerImageTagName
			Invoke-DockerRemoveImage $dockerImageName
		}
	}
	catch {
		Write-Error "Build failed: $_" -ErrorAction Continue
		exit 1
	}
	finally {
		popd
	}
}