#  PortAudio自動ビルドスクリプト for PowerShell

言語: [🌐(🇺🇸🇬🇧)](./README.md)

## 使い方

本リポジトリをクローンまたはサブモジュールとして追加するか、 `build_portaudio_win.ps1` をダウンロードして配置するかしてください。

あとは、本スクリプトを実行するだけです。Windowsで実行した場合、デフォルトでは、ASIO・WASAPIが有効になっています。

```powershell
.\build_portaudio_win.ps1
```

その後、ビルドされたライブラリ (静的・DLL) を、プロジェクトにコピーしてください。

```powershell
Copy-Item portaudio_build\Release\portaudio_x64.dll $USERPROFILE\path\to\your\project\build\Release\
```

## 要件

- Visual C++ 2019または2017 (Windowsのみ)
- CMake 3.13〜 (Visual Studio 2019付属で可)
- Ninja (VS付属で可、オプション)
- [WintellectPowerShell](https://github.com/Wintellect/WintellectPowerShell) (Windowsのみ)

## 主なオプション

| オプション名         | 説明                                              |
|-----------------|--------------------------------------------------|
| `-DebugBuild`   | デバッグ用のライブラリをビルドします。                              |
| `-PrefersNinja` | MSBuild(非WindowsではMake)の代わりにNinjaを利用してビルドします。 |
| `-DownloadOnly` | ダウンロードのみを行い、ビルドしません。                             |



## 非Windowsでのコンパイル

PowerShell 6以上をインストールすればLinux(・macOS)でもコンパイル可能です。Linuxでは

```bash
sudo snap install --classic powershell
```

でインストール可能です。インストールしたら、

```bash
pwsh ./build_portaudio_win.ps1
```

で実行します。


## ライセンス

MIT
