$ErrorActionPreference = 'Stop'
Set-PSDebug -Strict
$VerbosePreference = 'Continue'


function Invoke-DockerBuild([Parameter(Mandatory=$true)][string] $dockerImageName,
	[string] $dockerfilePath = './Dockerfile',
	[string] $extraParams = '',
	[string] $contextPath = '.') {

	Write-Verbose "Building docker image $dockerImageName with file $dockerfilePath and context path $contextPath (extraParams='$extraParams')..."
	docker build -t $dockerImageName -f $dockerfilePath $extraParams $contextPath
	if ($lastexitcode -ne 0) {
		throw "Docker build command failed with exit code $lastexitcode"
	}
}

function Invoke-DockerRemoveImage([Parameter(Mandatory=$true)][string] $dockerImageName) {

	Write-Verbose "Removing docker image $dockerImageName..."
	docker rmi $dockerImageName
	if ($lastexitcode -ne 0) {
		throw "Docker rmi command failed with exit code $lastexitcode"
	}
}

function Invoke-DockerLogin([Parameter(Mandatory=$true)][string] $registry, 
	[Parameter(Mandatory=$true)][string] $username,
	[Parameter(Mandatory=$true)][string] $password) {

	Write-Verbose "Logging out of $registry..."
	docker logout $registry

	if ($lastexitcode -ne 0) {
		throw "Docker logout command failed with exit code $lastexitcode"
	}

	Write-Verbose "Logging into $registry..."
	try {
		echo $password | docker login -u $username --password-stdin $registry
	} catch {
		throw "Docker login command failed: $_"
	}

	if ($lastexitcode -ne 0) {
		throw "Docker login command failed with exit code $lastexitcode"
	}
}

function Invoke-DockerTag([Parameter(Mandatory=$true)][string] $dockerImageName,
	[Parameter(Mandatory=$true)][string] $dockerImageTagName) {

	Write-Verbose "Tagging $dockerImageName with $dockerImageTagName..."
	docker tag $dockerImageName $dockerImageTagName
	if ($lastexitcode -ne 0) {
		throw "Docker tag command failed with exit code $lastexitcode"
	}
}

function Invoke-DockerPushImage([Parameter(Mandatory=$true)][string] $dockerImageName) {

	Write-Verbose "Pushing image $dockerImageName..."
	docker push $dockerImageName
	if ($lastexitcode -ne 0) {
		throw "Docker push command failed with exit code $lastexitcode"
	}
}

function Get-ImageNameChangeTag([Parameter(Mandatory=$true)][string] $dockerImageName, [string] $tag) {

	$versionIdx = $dockerImageName.LastIndexOf(':')
	$dockerImageName.Substring(0, $versionIdx) + ':' + $tag
}

function Invoke-DockerPush([Parameter(Mandatory=$true)][string] $dockerImageName,
	[Parameter(Mandatory=$true)][string] $dockerImageTagName,
	[switch] $skipLatestTag) {

	Invoke-DockerTag $dockerImageName $dockerImageTagName
	Invoke-DockerPushImage $dockerImageTagName

	if (-not $skipLatestTag) {

		$latest = Get-ImageNameChangeTag $dockerImageTagName 'latest'
		Invoke-DockerTag $dockerImageName $latest
		Invoke-DockerPushImage $latest
	}
}

function Invoke-DockerPull([Parameter(Mandatory=$true)][string] $dockerImageName) {

	Write-Verbose "Pulling image $dockerImageName..."
	docker pull $dockerImageName
	if ($lastexitcode -ne 0) {
		throw "Docker pull command failed with exit code $lastexitcode"
	}
}

function Invoke-DockerPullAndTag([Parameter(Mandatory=$true)][string] $dockerImageName,
	[Parameter(Mandatory=$true)][string] $dockerImageTagName) {

	Invoke-DockerPull $dockerImageName
	Invoke-DockerTag $dockerImageName $dockerImageTagName
}
