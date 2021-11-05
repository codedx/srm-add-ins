$VerbosePreference = 'Continue'
$ErrorActionPreference = 'Stop'
Set-PSDebug -Strict

function Invoke-GatherLicenseFiles(
	[Parameter(Mandatory=$true)][string] $appFolder,
	[Parameter(Mandatory=$true)][string] $licensesFolder) {

	push-location $appFolder
	write-verbose "Changed directory to '$appFolder'"

	write-verbose 'Adding and removing modules...'
	go mod tidy

	$sep = [io.path]::directoryseparatorchar
	$inclusion = [regex]::escape("$($sep)pkg$($sep)mod")

	$allDeps = go list -deps -f '{{if not .Standard}}{{.Module.Dir}}{{end}}'
	write-verbose "All dependencies: $allDeps"

	$deps = $allDeps | where-object { $_ -match $inclusion } | sort-object -Unique
	write-verbose "Found dependencies: $deps"

	$licenseFiles = $deps | foreach-object {
		write-verbose "Processing $_..."
		$dep = $_; $path = $null
		'LICENSE','LICENSE.txt','LICENSE.md' | ForEach-Object {
			$testPath = join-path $dep $_
			if (($null -eq $path) -and (test-path -PathType Leaf $testPath)) {
				write-verbose "Found path $testPath"
				$path = $testPath
			}
		}
		if (-not (test-path -PathType Leaf $path)) {
			throw "Cannot find license for $_"
		}
		$path
	}
	write-verbose "Found license files: $licenseFiles"

	if (test-path -PathType Container $licensesFolder) {
		write-verbose "Removing licenses under $licensesFolder..."
		remove-item $licensesFolder -recurse -force
	}

	write-verbose "Creating licenses folder at $licensesFolder..."
	new-item -ItemType Directory $licensesFolder | out-null

	$licenseFiles | foreach-object {
		$licenseFile = split-path $_ -Leaf
		$name = split-path (split-path $_) -Leaf
		$licenseDirectory = new-item -ItemType Directory (join-path $licensesFolder $name)

		write-verbose "Copying $licenseFile for $name to $($licenseDirectory.FullName)..."
		copy-item -LiteralPath $_ $licenseDirectory.FullName
	}

	pop-location
	write-verbose "Changed directory to '$((get-location).Path)'"
}
