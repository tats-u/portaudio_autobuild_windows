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
Build PortAudio without support of WASAPI (2nd Fastest)
.PARAMETER WDM
Build PortAudio with support of WDM (2nd Slowest)
.PARAMETER MME
Build PortAudio with support of MME (Slowest)
.PARAMETER DownloadOnly
Don't build.  Build it manually for example using Visual Studio.
.PARAMETER DebugBuild
Build PortAudio with Debug configuration.

.LINK
https://github.com/tats-u/portaudio_autobuild_windows
#>

[cmdletbinding()]
Param([switch]$NoASIO, [switch]$NoWASAPI, [switch]$WDM, [switch]$MME, [switch]$DownloadOnly, [switch]$DebugBuild)

$ErrorActionPreference = "Stop"

Push-Location

try {

  Set-Location $PSScriptRoot

  if (-not (Test-Path portaudio)) {
    Write-Verbose "PortAudio is not downloaded.  Installing it automatically..."
    Write-Verbose "Fetching information on the place of the latest PortAudio."
    $PortAudioDownloadPageContent = Invoke-WebRequest "http://www.portaudio.com/download.html"
    $LatestPortAudioRelativePath = ($PortAudioDownloadPageContent.ParsedHtml.getElementById("content").getElementsByTagName("a") |
      Where-Object { $_.pathname -like "*.tgz" })[0].pathname

    Write-Verbose "Downloading the latest PortAudio."
    Invoke-WebRequest "http://www.portaudio.com/$LatestPortAudioRelativePath" -OutFile portaudio.tgz
    tar xf portaudio.tgz
    Remove-Item .\portaudio.tgz
    if (-not (Test-Path portaudio -PathType Container)) {
      Write-Error "Folder portaudio was not created." -Category InvalidData -CategoryReason "portaudio.tgz did not contain directory portaudio."
      exit 1
    }
  }

  Set-Location portaudio
  # Fix typo preventing us from enabling WASAPI
  # See: https://app.assembla.com/spaces/portaudio/tickets/261/details
  $RootCMakeListsContent = Get-Content -Encoding UTF8 -Raw CMakeLists.txt
  if ($RootCMakeListsContent -match "`n *IF\(MSVS\) *`n") {
    Write-Verbose "Fixing bug in CMakeLists.txt in PortAudio."
    [IO.File]::WriteAllText("$PWD\CMakeLists.txt", $RootCMakeListsContent.Replace("IF(MSVS)", "IF(MSVC)"))
  }

  if (-not $NoASIO -and (-not (Test-Path src\hostapi\asio\ASIOSDK))) {
    Write-Verbose "Downloading ASIO SDK."
    Set-Location src\hostapi\asio
    Invoke-WebRequest https://www.steinberg.net/asiosdk -OutFile asiosdk.zip
    Expand-Archive -Path .\asiosdk.zip -DestinationPath .
    Remove-Item .\asiosdk.zip
    # The last \ is to specify a folder.
    # Just renaming ASIO SDK folder.
    Move-Item asiosdk_*.*.*_*\ ASIOSDK
  }

  if (-not $DownloadOnly) {
    if (Get-Command Import-VisualStudioEnvironment -ErrorAction Ignore) {
      Write-Verbose "Enabling Visual Studio Envirnoment."
      Import-VisualStudioEnvironment
    }
    else {
      Write-Warning "Command Import-VisualStudioEnvironment is not installed.  It can be installed by:`nInstall-Module -Name WintellectPowerShell -Scope CurrentUser"
    }
    $BuildType = if ($DebugBuild) { "Debug" } else { "Release" }
    Set-Location $PSScriptRoot\portaudio\build
    Write-Verbose "Configuring with CMake..."
    Write-Verbose "Build Type: $BuildType / ASIO: $(-not $NoASIO) / WASAPI: $(-not $NoWASAPI) / WDM: $WDM / MME: $MME"
    cmake .. -G "Visual Studio $((Get-Command msbuild).Version.Major)" -A x64 "-DPA_USE_ASIO=$(if($NoASIO) { 'OFF' } else { 'ON' })" "-DASIOSDK_ROOT_DIR=..\src\hostapi\asio\ASIOSDK" "-DPA_USE_WMME=$(if($MME) { 'ON' } else { 'OFF' })" "-DPA_USE_WASAPI=$(if($NoWASAPI) { 'OFF' } else { 'ON' })" "-DPA_USE_WDMKS=$(if($WDM) { 'ON' } else { 'OFF' })" -DPA_USE_DS=OFF "-DCMAKE_BUILD_TYPE=$BuildType"
    Write-Verbose "Build starting."
    msbuild portaudio.sln /t:build "/p:Configuration=$BuildType" /v:m /nologo
    Write-Output "PortAudio was successfully built.  Use $PWD\$BuildType\portaudio_x64.{dll,lib}."
  }

}
catch {
  throw
}
finally {
  Pop-Location
}
