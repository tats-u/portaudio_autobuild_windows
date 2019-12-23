# PortAudio Automatic Build Script for PowerShell

Languages: [🇯🇵](./README.ja.md)

## How to use

Clone or `git submodule add` this repo, or just download `build_portaudio_win.ps1`.

Then, all you have to do is just to execute the script.  ASIO & WASAPI are enabled by default in Windows.

```powershell
.\build_portaudio_win.ps1
```

And copy the built library files (static library / DLL) to your project.

```powershell
Copy-Item portaudio_build\Release\portaudio_x64.dll $USERPROFILE\path\to\your\project\build\Release\
```

## Requirements

- Visual C++ 2019 or 2017
- CMake 3.13+ (what is bundled in Visual Studio 2019 is acceptable)
- Ninja (what is bundled in VS is acceptable; optional)
- [WintellectPowerShell](https://github.com/Wintellect/WintellectPowerShell)

## Primary options

|Name|Description|
|------------|----|
|`-DebugBuild`|Builds for debug.|
|`-PrefersNinja`|Builds using Ninja instead of MSBuild (Make in non-Windows).|
|`-DownloadOnly`|Just downloads, doesn't build.|



## Compilation in non-Windows

You can build PortAudio by this script even in Linux (or macOS) if you install PowerShell 6+.  You can install it to Linux by:

```bash
sudo snap install --classic powershell
```

After installation, execute this script by:

```bash
pwsh ./build_portaudio_win.ps1
```

## License

MIT
