#  PortAudio自動ビルドスクリプト for Windows PowerShell

言語: [🌐(🇺🇸🇬🇧)](./README.md)

## 使い方

本スクリプトを実行するだけです。デフォルトでは、ASIO・WASAPIが有効になっています。

```powershell
.\build_portaudio_win.ps1
```

その後、ビルドされたライブラリ (静的・DLL) を、プロジェクトにコピーしてください。

```powershell
Copy-Item portaudio\build\Release\portaudio_x64.dll $USERPROFILE\path\to\your\project\build\Release\
```

## ライセンス

MIT
