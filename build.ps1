#-----------------------------------------------------------------------------
#
#  Copyright (c) 2025, Thierry Lelegard
#  BSD-2-Clause license, see LICENSE file
# 
#  Build the installer for the OpenSSL Libraries for Windows.
#
#-----------------------------------------------------------------------------

<#
 .SYNOPSIS

  Download, expand and install OpenSSL for Windows.

 .PARAMETER ForceDownload

  Force a download even if the OpenSSL installers are already downloaded.

 .PARAMETER NoInstall

  Do not install the OpenSSL packages, use already installed packages.
  By default, the latest versions of OpenSSL are installed.

 .PARAMETER NoPause

  Do not wait for the user to press <enter> at end of execution. By default,
  execute a "pause" instruction at the end of execution, which is useful
  when the script was run from Windows Explorer.
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [switch]$ForceDownload = $false,
    [switch]$NoInstall = $false,
    [switch]$NoPause = $false
)

# Description of the latest packages of OpenSSL.
$PackageList = "https://github.com/slproweb/opensslhashes/raw/master/win32_openssl_hashes.json"

# Description of OpenSSL packages.
$SSL = @{
    #
    # Key  = directory in final installer and in installed OpenSSL.
    # alt  = alternate directory name in installed OpenSSL.
    # arch = "arch" field in OpenSSL JSON configuration file.
    # bits = "bits" field in OpenSSL JSON configuration file.
    # root = installation root.
    #
    Win64 = @{
        alt  = "x64";
        arch = "intel";
        bits = 64;
        root = "C:\Program Files\OpenSSL-Win64"
    };
    Win32 = @{
        alt  = "x86";
        arch = "intel";
        bits = 32;
        root = "C:\Program Files (x86)\OpenSSL-Win32"
    }
    Arm64 = @{
        alt = "arm64";
        arch = "arm";
        bits = 64;
        root = "C:\Program Files\OpenSSL-Win64-ARM"
    };
}

# List of DLL's to grab for the OpenSSL installation. No extension, wildcard allowed.
$DLL = @(
    # Base libraries.
    "libcrypto*", "libssl*",
    # Crypto providers.
    "legacy", "p_minimal", "p_test",
    # Crypto engines.
    "capi", "dasync", "loader_attic", "padlock"
)

# Without this, Invoke-WebRequest is awfully slow.
$ProgressPreference = 'SilentlyContinue'

# Must be on an Arm64 system to install all architectures.
if (-not ($env:PROCESSOR_ARCHITECTURE -like "arm64")) {
    $SSL.Remove("Arm64")
    Write-Output
    Write-Output "========================= WARNING ========================="
    Write-Output "You are on a $($env:PROCESSOR_ARCHITECTURE) system."
    Write-Output "We can only install Win32 and Win64 versions of OpenSSL on this system."
    Write-Output "This is a limitation of the current packaging of OpenSSL for Windows."
    Write-Output "Run this script on an Arm64 system to build the installers with all"
    Write-Output "three architectures."
    Write-Output "==========================================================="
    Write-Output
}

# A function to exit this script.
function Exit-Script([string]$Message = "")
{
    $Code = 0
    if ($Message -ne "") {
        Write-Output "ERROR: $Message"
        $Code = 1
    }
    if (-not $NoPause) {
        pause
    }
    exit $Code
}

# Create a directory and return its name. Delete and recreate on -Reset.
function Get-Directory([string]$Path, [switch]$Reset=$false)
{
    if ($Reset -and (Test-Path -Path $Path)) {
        Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (-not (Test-Path -Path $Path -PathType Container)) {
        [void] (New-Item -Path $Path -ItemType Directory -Force)
    }
    if (-not (Test-Path -Path $Path -PathType Container)) {
        Exit-Script "Error creating directory $Path"
    }
    return $Path
}

# Local file names.
$RootDir = $PSScriptRoot
$TmpDir = Get-Directory "$RootDir\tmp"
$OutDir = Get-Directory "$RootDir\installers"

# Locate NSIS, the Nullsoft Scriptable Installation System.
Write-Output "Searching NSIS ..."
$NSIS = Get-Item "C:\Program Files*\NSIS\makensis.exe" | ForEach-Object { $_.FullName} | Select-Object -Last 1
if (-not $NSIS) {
    Exit-Script "NSIS not found"
}
Write-Output "NSIS: $NSIS"

# A function to get the JSON configuration file for OpenSSL downloads.
function Get-OpenSSL-Config()
{
    $status = 0
    $message = ""
    try {
        $response = Invoke-WebRequest -UseBasicParsing -UserAgent Download -Uri $PackageList
        $status = [int] [Math]::Floor($response.StatusCode / 100)
    }
    catch {
        $message = $_.Exception.Message
    }
    if ($status -ne 1 -and $status -ne 2) {
        if ($message -eq "" -and (Test-Path variable:response)) {
            Exit-Script "Status code $($response.StatusCode), $($response.StatusDescription)"
        }
        else {
            Exit-Script "#### Error accessing ${PackageList}: $message"
        }
    }
    return ConvertFrom-Json $Response.Content
}

# Download and install all MSI packages.
if (-not $NoInstall) {
    $packages = Get-OpenSSL-Config
    foreach ($Arch in $SSL.Keys) {

        # Get the URL of the MSI installer from the JSON config.
        $url = $packages.files | Get-Member | ForEach-Object {
            $info = $packages.files.$($_.name)
            if (-not $info.light -and $info.installer -like "msi" -and $info.bits -eq $SSL.$Arch.bits -and $info.arch -like $SSL.$Arch.arch) {
                $info.url
            }
        } | Select-Object -Last 1
        if (-not $Url) {
            Exit-Script "#### No MSI installer found for $($SSL.$Arch.bits)-bit $($SSL.$Arch.arch)"
        }

        $MsiName = (Split-Path -Leaf $url)
        $MsiPath = "$TmpDir\$MsiName"

        if (-not $ForceDownload -and (Test-Path $MsiPath)) {
            Write-Output "$MsiName already downloaded, use -ForceDownload to download again"
        }
        else {
            Write-Output "Downloading $Url ..."
            Invoke-WebRequest -UseBasicParsing -UserAgent Download -Uri $Url -OutFile $MsiPath
        }

        if (-not (Test-Path $MsiPath)) {
            Exit-Script "$url download failed"
        }

        Write-Output "Installing $MsiName"
        Start-Process msiexec.exe -ArgumentList @("/i", $MsiPath, "/qn", "/norestart") -Wait
    }
}

# Copy all files match a required DLL.
function Copy-Libraries([string]$InputDir, [string]$Extension, [string]$OutputDir)
{
    Get-ChildItem $InputDir -Filter "*.$Extension" | ForEach-Object {
        foreach ($template in $DLL) {
            if ($_.BaseName -like $template) {
                $_
                break
            }
        }
    } | Copy-Item -Destination $OutputDir
}

# Get OpenSSL version from include file. Verify it is the same version everywhere.
$Version = ""
foreach ($Arch in $SSL.Keys) {
    $header = "$($SSL.$Arch.root)\include\openssl\opensslv.h"
    $v = Get-Content $header | Select-String "^\s*#.*\sOPENSSL_FULL_VERSION_STR\s" | Select-Object -First 1
    if (-not $v) {
        Exit-Script "OpenSSL version not found in $header"
    }
    $v = $v -replace '.*\sOPENSSL_FULL_VERSION_STR\s+"(.[^"]*)".*','$1' -replace '\s',''
    Write-Output "OpenSSL version is $v in $($SSL.$Arch.root)"
    if ($Version -eq "") {
        $Version = $v
    }
    elseif ($Version -ne $v) {
        Exit-Script "Incompatible OpenSSL versions"
    }
}

# Split version string in pieces and make sure to get at least four elements with numbers.
$VField = ($Version -split '\D+') + @("0", "0", "0", "0")
$VersionInfo = "$($VField[0]).$($VField[1]).$($VField[2]).$($VField[3])"

# Build a tree of files to install.
$InstRoot = Get-Directory -Reset "$TmpDir\OpenSSL-WinLibs"
Copy-Item "$($SSL.Win64.root)\license.txt" $InstRoot
Copy-Item "$RootDir\props\*.props" $InstRoot
Copy-Item -Recurse "$RootDir\samples" $InstRoot

foreach ($Arch in $SSL.Keys) {
    $ArchDir = Get-Directory "$InstRoot\$Arch"
    $DllDir = Get-Directory "$InstRoot\$Arch\dll"
    $LibDir = Get-Directory "$InstRoot\$Arch\lib"
    Copy-Item -Recurse "$($SSL.$Arch.root)\include" "$InstRoot\$Arch"
    Copy-Libraries "$($SSL.$Arch.root)\bin" "dll" $DllDir
    # Find the MD, MDd, MT, MTd directories.
    $InputLib = Get-ChildItem -Recurse "$($SSL.$Arch.root)\lib" -Include "MD" | Select-Object -First 1
    if (-not $InputLib) {
        Exit-Script "Directory MD not found in $($SSL.$Arch.root)\lib"
    }
    $InputLib = Split-Path -Parent $InputLib
    foreach ($dir in @("MD", "MDd", "MT", "MTd")) {
        if (-not (Test-Path -Path "$InputLib\$dir" -PathType Container)) {
            Exit-Script "Directory $InputLib\$dir not found"
        }
        $OutputLib = Get-Directory "$LibDir\$dir"
        Copy-Libraries "$InputLib\$dir" "def" $OutputLib
        Copy-Libraries "$InputLib\$dir" "lib" $OutputLib
    }
}

# Build the binary installer.
$InstallExe = "$OutDir\OpenSSL-WinLibs-$Version.exe"

Write-Output "Building installer ..."
& $NSIS /V2 `
    /DVersion="$Version" `
    /DVersionInfo="$VersionInfo" `
    /DOutFile="$InstallExe" `
    /DInDir="$InstRoot" `
    "$RootDir\openssl-winlibs.nsi" 

if (-not (Test-Path $InstallExe)) {
    Exit-Script "**** Missing $InstallExe"
}
Write-Output "Installer: $InstallExe"

Exit-Script
