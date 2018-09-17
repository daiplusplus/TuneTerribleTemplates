Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

###########################################
## Summary

# This script changes the namespace imports in your C# ItemTemplates and ProjectTemplates and improves your default AssemblyInfo.cs files.
# It is designed for Visual Studio 2017, but should work with all Visual Studio versions going back as far as Visual Studio 2002, just set $vsCommon7IDE correctly.

###########################################
## Details

# This script does the following:
# 1. Copies all C# files from your Visual Studio ItemTemplates and ProjectTemplates directories in the VS installation folder.
# 2. Adds `using` namespace imports to every C# file that already has at least 1 other `using` statement:
#   1. System.Globalization
#   2. System.Text
# 3. Changes `AssemblyInfo.cs` files:
#   1. Adding `using System;`
#   2. Adding `[assembly: CLSCompliant( isCompliant: true )]`
#   3. Changes `[assembly: AssemblyVersion("1.0.0.0")]` to `[assembly: AssemblyVersion("1.0.*")]`
#   4. Comments-out `[assembly: AssemblyFileVersion("1.0.0.0")]` (the compiler uses AssemblyVersion for AssemblyFileVersion if AssemblyFileVersion is not present)
# 4. This script does not copy the files back into Program Files because it needs elevated permissions for that; but you can just cut+paste them with File Explorer.

###########################################
## Instructions

$vsCommon7IDE = "auto" # Set to 'auto' to autodiscover the VS2017 installation location. Requires VS2017 15.2 or later. Otherwise set it to the "Common7\IDE" directory's absolute path.
$useGit       = $false  # Set this to `$true` to create a repo with the original files and then adds the changes so you can see the diffs. Ensure 'git' works in your PowerShell first.

###########################################
## You don't need to edit anything below this line.

If( $vsCommon7IDE -eq "auto" ) {

	$vsWherePath = "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
	$vsWherePath = [System.Environment]::ExpandEnvironmentVariables( $vsWherePath )

	If( -not (Test-Path $vsWherePath) ) {
		Throw "Could not find vswhere.exe. Do you have Visual Studio 2017 version 15.2 or later installed? Set 'vsTemplatePath' in this script to the directory name otherwise."
	}

	$vsInstallPath = & $vsWherePath | Select-String "installationPath: (.+)" | %{ $_.Matches.Groups[1].Value }

	If( -not (Test-Path $vsInstallPath) ) {
		Throw "`"$vsInstallPath`" does not exist."
	}

	$vsCommon7IDE = (Join-Path -Path $vsInstallPath -ChildPath "Common7\IDE")
}

$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False

$fileCount = 0

function Update-CSharpItemTemplate {
	[CmdletBinding()]
	param(
		[Parameter(ValueFromPipeline)] [System.IO.FileInfo]$fileInfo,
		[string]$workingDirectoryPath
	)

	Begin { }
	Process {
	
		$encoding = Get-FileEncoding $fileInfo.FullName -DefaultEncoding $Utf8NoBomEncoding
		$newFileContent = $null

		$fileContent = Get-Content $fileInfo.FullName -Raw # -Raw returns a single string, not an array of lines
		$newFileContent = $fileContent

		$relativeFileName = $fileInfo.FullName.Substring( $workingDirectoryPath.Length )

		If( $newFileContent -eq $null -or $newFileContent.Length -eq 0 ) {
		
			Write-Host "Skipped empty file: $relativeFileName"
			return
		}
		ElseIf( $newFileContent.Length -lt 25 ) {
			
			Write-Host "Skipped short file: $relativeFileName, Length: $($fileContent.Length)"
			return
		}

		If( -not $newFileContent.Trim().StartsWith("using") ) {
			
			Write-Host "Skipped non-using file: $relativeFileName"
			return
		}

		If( $fileInfo.Name -ieq "AssemblyInfo.cs" ) { # `-ieq` is Case-insensitive string equality
			
			If( $newFileContent -notmatch "using System;" ) {
			
				$newFileContent = "using System;`r`n" + $newFileContent
			}

			# these two are string-replace operations, so no need to do a match check first:
			$newFileContent = $newFileContent -replace "\[assembly: AssemblyVersion\(`"1\.0\.0\.0`"\)\]", "[assembly: AssemblyVersion(`"1.0.*`")]"
			$newFileContent = $newFileContent -replace "`n\[assembly: AssemblyFile", "`n//[assembly: AssemblyFile"
			

			If( $newFileContent -notmatch "CLSCompliant" ) {

				$newFileContent = $newFileContent + "`r`n[assembly: CLSCompliant( isCompliant: true )]`r`n"
			}
		}
		Else {
			
			If( $newFileContent -notmatch "using System.Globalization;" ) {
			
				If( $newFileContent -match "using System\.Collections\.Generic;" ) {
				
					$newFileContent = $newFileContent -replace "using System\.Collections\.Generic;", "using System.Collections.Generic;`r`nusing System.Globalization;"
				}
				Else {
				
					# add it to the start of the file:
					$newFileContent = $newFileContent.Replace( "using System;`r`n", "" )
					$newFileContent = "using System;`r`nusing System.Globalization;`r`n" + $newFileContent
				}
			}

			If( $newFileContent -notmatch "using System.Text;" ) {
			
				If( $newFileContent -match "using System\.Threading\.Tasks;" ) {
				
					$newFileContent = $newFileContent -replace "using System\.Threading\.Tasks;", "using System.Text;`r`nusing System.Threading.Tasks;"
				}
				Else {
				
					# add it to the start of the file:
					$newFileContent = $newFileContent.Replace( "using System;`r`n", "" )
					$newFileContent = "using System;`r`nusing System.Text;`r`n" + $newFileContent
				}
			}

		}

		#$newFileContent | Out-File $fileInfo.FullName -encoding ascii # using ASCII encoding instead of UTF8 to avoid BOM. Using non-BOM UTF8 in powershell is non-trivial.

		[System.IO.File]::WriteAllText( $fileInfo.FullName, $newFileContent, $encoding )

		$script:fileCount = $script:fileCount + 1

	}
	End { }
}

# from https://vertigion.com/2015/02/04/powershell-get-fileencoding/
function Get-FileEncoding {
	[CmdletBinding()]
	param (
		[Alias("PSPath")]
		[Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)]
		[String]$Path
		,
		[Parameter(Mandatory = $False)]
		[System.Text.Encoding]$DefaultEncoding = $null
	)
	
	process {
		[Byte[]]$bom = Get-Content -Encoding Byte -ReadCount 4 -TotalCount 4 -Path $Path
		
		$encoding_found = $false
		
		foreach ($encoding in [System.Text.Encoding]::GetEncodings().GetEncoding()) { # how does this work? `GetEncodings()` returns an array, so how does the subsequent `GetEncoding()` call work?
			$preamble = $encoding.GetPreamble()
			if ($preamble) {
				foreach ($i in 0..$preamble.Length) {
					if ($preamble[$i] -ne $bom[$i]) {
						break
					} elseif ($i -eq $preamble.Length) {
						$encoding_found = $encoding
					}
				}
			}
		}
		
		if (!$encoding_found) {
			$encoding_found = $DefaultEncoding
		}
	
		$encoding_found
	}
}

# Create directory:
New-Item -ItemType Directory -Force -Path "VS2017Templates"
cd "VS2017Templates"
$workingDirectoryPath = Resolve-Path "."

If( $useGit ) {
	git init
}

$itemTemplates = Join-Path $vsCommon7IDE "ItemTemplates"
$projTemplates = Join-Path $vsCommon7IDE "ProjectTemplates"

Copy-Item -Path $itemTemplates -Filter *.cs -Destination "ItemTemplates"    -Recurse
Copy-Item -Path $projTemplates -Filter *.cs -Destination "ProjectTemplates" -Recurse

If( $useGit ) {
	git add *
	git commit -m "Initial state of C# templates from Visual Studio."
}

Get-ChildItem -Path . -File -Filter *.cs -Recurse | Update-CSharpItemTemplate -workingDirectoryPath $workingDirectoryPath

If( $useGit ) {
	git add *
	git commit -m "After updating templates."
}

Write-Host "$fileCount files were updated. You need to manually (with elevated permissions) overwrite the original template files in `"$vsCommon7IDE`"."
