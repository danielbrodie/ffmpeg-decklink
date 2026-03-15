# ffmpeg-decklink

Pre-built ffmpeg binaries with Blackmagic DeckLink capture card support, for use with [osc-record](https://github.com/danielbrodie/osc-record) and other projects that need DeckLink ingest.

## Quick install

### macOS (Apple Silicon)

```bash
curl -L https://github.com/danielbrodie/ffmpeg-decklink/releases/latest/download/ffmpeg-decklink-darwin-arm64.tar.gz | tar xz
sudo mv ffmpeg-decklink /usr/local/bin/
```

### Windows (x64)

```powershell
# PowerShell
Invoke-WebRequest -Uri "https://github.com/danielbrodie/ffmpeg-decklink/releases/latest/download/ffmpeg-decklink-windows-amd64.zip" -OutFile ffmpeg-decklink.zip
Expand-Archive ffmpeg-decklink.zip -DestinationPath C:\ffmpeg-decklink
# Add C:\ffmpeg-decklink to your PATH, or point osc-record at the full path
```

## What is in the binary

Both builds include:

| Feature | Notes |
|---|---|
| DeckLink ingest (`-f decklink`) | Blackmagic DeckLink SDK 15.3 |
| H.264 encode (`libx264`) | GPL |
| H.265/HEVC encode (`libx265`) | GPL |
| Hardware accel (macOS) | VideoToolbox + AudioToolbox |
| Static build | Single executable, no ffmpeg deps |

### Windows — bundled DLLs

The Windows zip includes the MinGW runtime and codec DLLs required at runtime. Keep all files in the same directory as `ffmpeg-decklink.exe`:

```
ffmpeg-decklink.exe
libgcc_s_seh-1.dll
libstdc++-6.dll
libwinpthread-1.dll
libx264-165.dll
libx265-215.dll
libbz2-1.dll
libiconv-2.dll
liblzma-5.dll
zlib1.dll
```

> **Note:** DLL filenames are versioned and reflect the MinGW toolchain version used at build time. If you update the toolchain, re-enumerate dependencies with `objdump -p ffmpeg-decklink.exe | grep "DLL Name"`.

## Releases

Each release is tagged `vYYYY-MM-DD` (date of build). Assets:

| File | Platform |
|---|---|
| `ffmpeg-decklink-darwin-arm64.tar.gz` | macOS Apple Silicon |
| `ffmpeg-decklink-windows-amd64.zip` | Windows x64 |

## Building from source

See [`build/windows/build.sh`](build/windows/build.sh) for the full automated Windows build script (runs under MSYS2).

### macOS

Prerequisites: Homebrew, DeckLink SDK 15.3 headers in `/opt/homebrew/include`.

```bash
brew tap homebrew-ffmpeg/ffmpeg
brew install homebrew-ffmpeg/ffmpeg/ffmpeg --with-decklink
```

Or build manually with:

```bash
./configure \
  --enable-gpl \
  --enable-nonfree \
  --enable-decklink \
  --enable-libx264 \
  --enable-libx265 \
  --enable-videotoolbox \
  --enable-audiotoolbox \
  --extra-cflags=-I/opt/homebrew/include \
  --extra-cxxflags=-I/opt/homebrew/include \
  --extra-ldflags=-L/opt/homebrew/lib
```

### Windows

See [`build/windows/build.sh`](build/windows/build.sh). Requires:

- MSYS2 (`winget install MSYS2.MSYS2`)
- MinGW64 toolchain (`mingw-w64-x86_64-gcc`, `mingw-w64-x86_64-x264`, `mingw-w64-x86_64-x265`)
- DeckLink SDK 15.3 extracted to `~/decklink-sdk/`

The script handles IDL to header generation, the Windows COM dispatch file, the GNU Make response-file patch, and DLL bundling automatically.

## License

The ffmpeg binary is licensed under the GPL (due to libx264/libx265). See the [FFmpeg license page](https://ffmpeg.org/legal.html) for details.

Blackmagic DeckLink SDK headers are copyright Blackmagic Design and are used here solely as build-time inputs per the SDK license.

