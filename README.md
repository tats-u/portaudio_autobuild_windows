# PortAudio Automatic Build Script for Windows PowerShell

Languages: [🇯🇵](./README.ja.md)

## How to use

Clone or `git submodule add` this repo, or just download `build_portaudio_win.ps1`.

Then, all you have to do is just to execute the script.  ASIO & WASAPI are enabled by default.

```powershell
.\build_portaudio_win.ps1
```

And copy the built library files (static library / DLL) to your project.

```powershell
Copy-Item portaudio\build\Release\portaudio_x64.dll $USERPROFILE\path\to\your\project\build\Release\
```

## License

MIT
