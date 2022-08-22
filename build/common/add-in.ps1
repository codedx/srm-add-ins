<#PSScriptInfo
.VERSION 1.1.0
.GUID 6e54ccbc-2837-4839-9faf-2024219585d8
.AUTHOR Code Dx
#>

<#
.DESCRIPTION
This script contains helpers for writing pwsh-based add-ins.
#>

Set-PSDebug -Strict

function Exit-Script([string] $err, [int] $exitCode=1) {

	$local:VerbosePreference = 'Continue'
	Write-Verbose $err
	exit $exitCode
}

function Test-AppCommandPath([string] $commandName) {

	$null -ne (Get-AppCommandPath $commandName)
}

function Get-AppCommandPath([string] $commandName) {

	$command = Get-Command $commandName -Type Application -ErrorAction SilentlyContinue
	if ($null -eq $command) {
		return $null
	}
	$command.Path
}

function Get-Config([string] $configPath) {

	if (-not (Test-AppCommandPath 'toml2json')) {
		"Unable to find toml2json - is it in your PATH?" | ForEach-Object { Write-Verbose $_; throw $_ }
	}

	$jsonConfigPath = [io.path]::changeextension($configPath, "json")
	if (Test-Path $jsonConfigPath -PathType Leaf) {
		Remove-Item $jsonConfigPath -Force
	}

	try {
		toml2json -tomlFile $configPath -jsonFile $jsonConfigPath
		if ($lastexitcode -ne 0) {
			"TOML to JSON conversion failed with exit code $lastexitcode" | ForEach-Object { Write-Verbose $_; throw $_ }
		}
		Get-Content $jsonConfigPath | ConvertFrom-Json
	}
	finally {
		Remove-Item $jsonConfigPath -ErrorAction Ignore
	}
}

function Get-FirstLargestFileInfo([string] $folder, [string[]] $include) {
	$fileInfo = $null
	$include | ForEach-Object {
		if ($null -eq $fileInfo) {
			$info = Get-ChildItem -path $folder -include $_ -recurse | Sort-Object -Property Length -Descending | Select-Object -First 1
			if ($null -ne $info) {
				$fileInfo = $info
			}
		}
	}
	$fileInfo
}

function Get-FileContents([string] $path) {
	[string]::join('', (Get-Content $path)).trim()
}

function Set-OptionsEnvironmentVariables([string[]] $options, [string[]] $allowedEnvironmentVariables) {

	$convertedOptions = @()
	$options | ForEach-Object {
		$option = $_

		$envVarMatches = $option | select-string -Pattern '(?<var>\$\S+)' -AllMatches
		if ($null -ne $envVarMatches) {

			$envVarMatches.Matches | ForEach-Object {
				$envVarMatchValue = $_.Value

				if ($allowedEnvironmentVariables -notcontains $envVarMatchValue) { 
					"Environment variable '$envVarMatchValue' is not allowed" | ForEach-Object { Write-Verbose $_; throw $_ }
				}
				$option = invoke-expression "[environment]::ExpandEnvironmentVariables(""$option"")"
			}
		}
		$convertedOptions += $option
	}
	$convertedOptions
}

function Set-Tlsv12 {

	# Make sure PowerShell is using TLSv1.2 to avoid this message:
	#
	#   Invoke-RestMethod : The underlying connection was closed: An unexpected error occurred on a send.
	#
	[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
}

function Push-BaseSourceCodeDirectory([string] $defaultDirectory, [string] $relativeDirectory, [string[]] $projectFileDirectoryPatterns) {

	$hasRelativeDirectory = ('' -ne $relativeDirectory) -and -not ([string]::IsNullOrWhiteSpace($relativeDirectory))
	$hasProjectFileDirectoryPatterns = $projectFileDirectoryPatterns.Count -gt 0

	$sourceDir = $defaultDirectory
	if ($hasRelativeDirectory) {

		write-verbose "Searching source code directory ($sourceDir) with relative directory $relativeDirectory..."
		$foundFolder = Get-ChildItem -Directory -Recurse $sourceDir | ForEach-Object {
			$relativePath = [io.path]::GetRelativePath($sourceDir, $_.FullName)
			write-verbose $relativePath
			$relativePath
		} | Where-Object { $relativeDirectory -eq $_ }
	
		if ($null -eq $foundFolder) {
			Exit-Script "Cannot find a new source directory from $sourceDir using relative directory $relativeDirectory"
		}
		$sourceDir = join-path $sourceDir $foundFolder
	
	} elseif ($hasProjectFileDirectoryPatterns) {
	
		write-verbose "Searching source code directory ($sourceDir) with patterns $projectFileDirectoryPatterns..."
		$foundFile = Get-FirstLargestFileInfo $sourceDir $projectFileDirectoryPatterns
	
		if ($null -eq $foundFile) {
			Exit-Script "Cannot find a new source directory from $sourceDir using file search patterns $projectFileDirectoryPatterns"
		}
		$sourceDir = split-path $foundFile
	
	}

	write-verbose "Using source code directory $sourceDir..."
	Push-Location $sourceDir
	$Env:CodeDxAddInSourceDir = $sourceDir

	$sourceDir
}

function Expand-SourceArchive([string] $path, [string] $destinationPath, [switch] $restoreGitDirectory) {

	write-verbose "Expanding $path to $destinationPath..."
	Expand-Archive $path $destinationPath -Force

	Get-ChildItem -LiteralPath $destinationPath -Filter '.gitdir' -Recurse -Force -Directory | ForEach-Object {

		$gitDirReplacement = $_

		$gitDirCurrent = Join-Path (Split-Path $gitDirReplacement) '.git'
		if (Test-Path $gitDirCurrent -PathType Container) {
			write-verbose "Removing current git directory '$gitDirCurrent'..."
			Remove-Item $gitDirCurrent -Recurse -Force
		}

		write-verbose "Restoring git directory '$gitDirReplacement'..."
		Rename-Item $gitDirReplacement '.git'
	}
}

function Get-KeystorePasswordEscaped([string] $pwd) {
	$pwd.Replace('"','\"')
}

function Add-KeystoreAlias([string] $keystorePath, [string] $keystorePwd, [string] $aliasName, [string] $certFile) {

	keytool -import -trustcacerts -keystore $keystorePath -file $certFile -alias $aliasName -noprompt -storepass (Get-KeystorePasswordEscaped $keystorePwd)
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to import certificate '$certFile' into keystore, keytool exited with code $LASTEXITCODE."
	}
}

function Add-TrustedCertsJava([string] $workDirectory, [string] $keystorePath, [string] $keystorePwd) {

	$certsDirectory = join-path $workDirectory 'ca-certificates'
	Get-ChildItem -path $certsDirectory -file -recurse | ForEach-Object {
		write-verbose "Adding certificate $_ to $keystorePath..."
		Add-KeystoreAlias $keystorePath $keystorePwd (split-path $_ -leaf) $_
	}
}

function Start-SleepFile([string] $directory) {

	$sleepFile = join-path $directory 'sleeping-while-this-file-exists'
	New-Item $sleepFile -ItemType file
	while (Test-Path $sleepFile -PathType leaf) {
		Start-Sleep -Seconds 5
	}
}

if ($PSVersionTable.PSEdition -ne 'Core') {
	Exit-Script "$($PSVersionTable.PSEdition) is unsupported - you must run this script with PowerShell Core"
}
