#!/usr/bin/env pwsh

<#
.SYNOPSIS
Build PortAudio Automatically
.DESCRIPTION
This script builds PortAudio (http://www.portaudio.com) with WASAPI & ASIO support in the folder .\portaudio.
You don't have to run Visual Studio anymore.

Copyright (C) 2019 Tatsunori Uchino
MIT License (See https://github.com/tats-u/portaudio_autobuild_windows/blob/master/LICENSE)
.EXAMPLE
.\build_portaudio_win.ps1
Builds PortAudio with default options.
.EXAMPLE
.\build_portaudio_win.ps1 -Verbose -DebugBuild -NoWASAPI
Builds PortAudio with support only of ASIO, with more messages, and with debug symbols.
Built libraries are at portaudio\build\Debug.
.EXAMPLE
.\build_portaudio_win.ps1 -DownloadOnly
Downloads PortAudio.
Build it manually by, for example, http://portaudio.com/docs/v19-doxydocs/compile_windows.html
or http://portaudio.com/docs/v19-doxydocs/compile_windows_asio_msvc.html .
.PARAMETER NoASIO
Build PortAudio without support of ASIO (Fastest but requires automatically-downloaded SDK)
.PARAMETER NoWASAPI
Build PortAudio without support of WASAPI (2nd fastest)
.PARAMETER WDM
Build PortAudio with support of WDM (2nd slowest)
.PARAMETER MME
Build PortAudio with support of MME (Slowest)
.PARAMETER DownloadOnly
Don't build.  Build it manually for example using Visual Studio.
.PARAMETER DebugBuild
Build PortAudio with Debug configuration.
.PARAMETER BuildRoot
Build root directory.  Library will be created at $BuildRoot\{Debug,Release}\.
.PARAMETER PrefersNinja
Build using Ninja instead of MSBuild (or Make in non-Windows) if possible

.LINK
https://github.com/tats-u/portaudio_autobuild_windows
#>

[cmdletbinding()]
Param([switch]$NoASIO, [switch]$NoWASAPI, [switch]$WDM, [switch]$MME, [switch]$DownloadOnly, [switch]$DebugBuild, [string]$BuildRoot = "$PSScriptRoot\portaudio_build", [switch]$PrefersNinja)

$ErrorActionPreference = "Stop"

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$VSWhereFound = Test-Path $vswhere -PathType Leaf

$IsWin = if (Test-Path variable:IsWindows) {
  # PowerShell 6+
  $IsWindows
}
else {
  # PowerShell 5-
  Test-Path $env:windir
}

Push-Location

try {

  Set-Location $PSScriptRoot

  if (-not (Test-Path portaudio)) {
    Write-Verbose "PortAudio is not downloaded.  Installing it automatically..."
    Write-Verbose "Fetching information on the place of the latest PortAudio."
    $PortAudioDownloadPageContent = Invoke-WebRequest "http://www.portaudio.com/download.html"
    $LatestPortAudioRelativePath = ($PortAudioDownloadPageContent.Links |
      Where-Object { $_.href -like "*.tgz" })[0].href

    Write-Verbose "Downloading the latest PortAudio."
    Invoke-WebRequest "http://www.portaudio.com/$LatestPortAudioRelativePath" -OutFile portaudio.tgz
    tar xf portaudio.tgz
    Remove-Item portaudio.tgz
    if (-not (Test-Path portaudio -PathType Container)) {
      Write-Error "Folder portaudio was not created." -Category InvalidData -CategoryReason "portaudio.tgz did not contain directory portaudio."
      exit 1
    }
  }

  Push-Location
  try {
    Set-Location portaudio
    # Fix typo preventing us from enabling WASAPI
    # See: https://app.assembla.com/spaces/portaudio/tickets/261/details
    $RootCMakeListsContent = Get-Content -Encoding UTF8 -Raw CMakeLists.txt
    if ($RootCMakeListsContent -match "`n *IF\(MSVS\) *`n") {
      Write-Verbose "Fixing bug in CMakeLists.txt in PortAudio."
      [IO.File]::WriteAllText((Join-Path $PWD "CMakeLists.txt"), $RootCMakeListsContent.Replace("IF(MSVS)", "IF(MSVC)"))
    }

    if ($IsWin -and -not $NoASIO -and (-not (Test-Path src\hostapi\asio\ASIOSDK))) {
      Write-Verbose "Downloading ASIO SDK."
      Set-Location src\hostapi\asio
      Invoke-WebRequest https://www.steinberg.net/asiosdk -OutFile asiosdk.zip
      Expand-Archive -Path asiosdk.zip -DestinationPath .
      Remove-Item asiosdk.zip
      # The last \ is to specify a folder.
      # Just renaming ASIO SDK folder.
      Move-Item asiosdk_*.*.*_*\ ASIOSDK
    }
  }
  catch {
    throw
  }
  finally {
    Pop-Location
  }

  if (-not $DownloadOnly) {
    if ($IsWin -and -not (Get-Command cl -ErrorAction Ignore)) {
      if (
        (Get-Command Import-VisualStudioEnvironment -ErrorAction Ignore) -and
        (
          -not $VSWhereFound -or
          ((& $vswhere -latest -property catalog_productLineVersion) -in (Get-Command Import-VisualStudioEnvironment).Parameters.VSVersion.Attributs.ValidValues)
        )
      ) {
        Write-Verbose "Enabling Visual Studio Envirnoment using Import-VisualStudioEnvironment."
        Import-VisualStudioEnvironment
      }
      elseif ((Get-Command invoke-CmdScript -ErrorAction Ignore) -and $VSWhereFound) {
        Write-Verbose "Enabling Visual Studio Envirnoment using Invoke-CmdScript."
        $VCVars64 = & $vswhere -latest -find "VC\Auxiliary\Build\vcvars64.bat"
        if ($null -ne $VCVars64) {
          Invoke-CmdScript $VCVars64
        }
        else {
          Write-Error "Visual C++ seems not to be installed to Visual Studio." -Category NotInstalled
          exit 1
        }
      }
      else {
        Write-Error "Command Import-VisualStudioEnvironment is not installed.  It can be installed by:`nInstall-Module -Name WintellectPowerShell -Scope CurrentUser" -Category NotInstalled
        exit 1
      }
    }
    $BuildType = if ($DebugBuild) { "Debug" } else { "Release" }
    $VSVersion = if ($IsWin) {
      # ($var1 = $env:ENV) returns $true only if $env:ENV is truely (not 0, $null, or @())
      if (
        ($_VSFullVersion = $env:VisualStudioVersion) -or
        ($_VSFullVersion = $env:VSCMD_VER)
      ) {
        $_VSFullVersion -replace "\..*", ""
      }
      elseif ($VSWhereFound) {
        # - ($var = command args) -and $? returns $true only if command args succeeded
        # - old vswhere doesn't support -path option
        if (
          (($_VSFullVersion = & $vswhere -path (Get-Command cl).Path -property installationVersion) -and $?) -or
          ((($_VSFullVersion = & $vswhere -latest -property installationVersion) -and $?))
        ) {
          $_VSFullVersion -replace "\..*", ""
        }
        else {
          (Get-Command msbuild).Version.Major
        }
      }
      else {
        (Get-Command msbuild).Version.Major
      }
    }
    else {
      "" # HACK: for avoiding error in non-Windows
    }
    $UseNinja = ($PrefersNinja) -and (Get-Command ninja -ErrorAction Ignore)
    $CMakeTarget = if ($UseNinja) { "Ninja" } elseif ($IsWin) { "Visual Studio $VSVersion" } else { "Unix Makefiles" }
    $UseMSBuild = $IsWin -and -not $UseNinja
    if (-not $UseMSBuild) {
      $BuildRoot = join-path $BuildRoot $BuildType
    }
    if (-not (Test-Path $BuildRoot)) {
      if (New-item -type Directory $BuildRoot) {
        Write-Verbose "Created a directory: $BuildRoot"
      }
    }
    Push-Location
    try {
      Set-Location $BuildRoot
      $PortAudioRealativeRootFromBuildDir = Resolve-Path -Relative (Join-Path $PSScriptRoot portaudio)
      Write-Verbose "Configuring with CMake..."
      Write-Verbose "Build Type: $BuildType / ASIO: $(-not $NoASIO) / WASAPI: $(-not $NoWASAPI) / WDM: $WDM / MME: $MME"
      Write-Verbose "Build starting."
      $CMakeArgs = ($PortAudioRealativeRootFromBuildDir, "-G", $CMakeTarget)
      if ($UseMSBuild) {
        $CMakeArgs += ("-A", "x64")
      }
      if ($IsWin) {
        $CMakeArgs += ("-DPA_USE_ASIO=$(if($NoASIO) { 'OFF' } else { 'ON' })", "-DASIOSDK_ROOT_DIR=$(Join-Path $PortAudioRealativeRootFromBuildDir src | Join-Path -ChildPath hostapi | Join-Path -ChildPath asio | Join-Path -ChildPath ASIOSDK)", "-DPA_USE_WMME=$(if($MME) { 'ON' } else { 'OFF' })", "-DPA_USE_WASAPI=$(if($NoWASAPI) { 'OFF' } else { 'ON' })", "-DPA_USE_WDMKS=$(if($WDM) { 'ON' } else { 'OFF' })", "-DPA_USE_DS=OFF")
      }
      $CMakeArgs += "-DCMAKE_BUILD_TYPE=$BuildType"
      cmake $CMakeArgs
      cmake --build . --config "$($BuildType.ToLower())"
      Write-Output "PortAudio was successfully built.  Use $(Join-Path $(if ($UseMSBuild) { (Join-Path $PWD $BuildType) } else { $PWD  }) "portaudio_x64.{dll,lib}")."
    }
    catch {
      throw
    }
    finally {
      Pop-Location
    }
  }

}
catch {
  throw
}
finally {
  Pop-Location
}
