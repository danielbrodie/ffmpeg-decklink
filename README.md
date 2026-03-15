# ffmpeg-decklink

Pre-built ffmpeg binaries with Blackmagic DeckLink support, for use with [osc-record](https://github.com/danielbrodie/osc-record).

## Download

| Platform | File | Notes |
|----------|------|-------|
| macOS arm64 | `ffmpeg-decklink-darwin-arm64.tar.gz` | Apple Silicon |
| Windows x64 | `ffmpeg-decklink-windows-amd64.zip` | Includes required DLLs |

See [Releases](https://github.com/danielbrodie/ffmpeg-decklink/releases).

## What's in the binary

Both builds include:
- `--enable-decklink` — native Blackmagic DeckLink input/output
- `--enable-libx264` — H.264 encoding
- `--enable-libx265` — HEVC encoding
- `--enable-gpl --enable-nonfree`

macOS also includes `--enable-videotoolbox --enable-audiotoolbox`.

The Windows zip bundles required MinGW runtime and codec DLLs alongside `ffmpeg-decklink.exe` so no separate installation is needed.

## Requirements

- [Blackmagic Desktop Video](https://www.blackmagicdesign.com/support) drivers 14.3+ installed on the host machine
- For Windows: DeckLink CLSIDs are registered by the Desktop Video installer — the binary uses COM to find the device

---

## Building

### macOS

macOS builds use Homebrew with the `homebrew-ffmpeg/ffmpeg` tap:

```sh
brew tap homebrew-ffmpeg/ffmpeg
brew install homebrew-ffmpeg/ffmpeg/ffmpeg --with-decklink
```

Place the DeckLink SDK headers in a path accessible to the build (e.g. `/opt/homebrew/include`).

**Configure flags used:**
```
--prefix=/opt/homebrew
--enable-gpl --enable-nonfree --enable-decklink
--enable-libx264 --enable-libx265
--enable-videotoolbox --enable-audiotoolbox
--extra-cflags=-I/opt/homebrew/include
--extra-cxxflags=-I/opt/homebrew/include
--extra-ldflags=-L/opt/homebrew/lib
```

---

### Windows (MSYS2/MinGW64)

This is the non-obvious one. Full details below.

#### 1. Install prerequisites

Install [MSYS2](https://www.msys2.org/) (e.g. `winget install MSYS2.MSYS2`), then from an MSYS2 MinGW64 shell:

```bash
pacman -S mingw-w64-x86_64-gcc \
          mingw-w64-x86_64-x264 \
          mingw-w64-x86_64-x265 \
          diffutils zip

# make is not in PATH by default in MinGW64:
ln -sf /mingw64/bin/mingw32-make.exe /usr/bin/make
```

#### 2. Get the DeckLink SDK

Download the DeckLink SDK from [Blackmagic Design](https://www.blackmagicdesign.com/support) and extract it to `~/decklink-sdk/`. The SDK ships `.idl` files on Windows (COM Interface Definition Language), not pre-compiled headers.

#### 3. Generate headers from IDL

Use `widl` (the Wine IDL compiler, included in MinGW) to generate `.h` and `_i.c` files from the `.idl` source:

```bash
cd ~/decklink-sdk

# Generate DeckLinkAPI.h (all interface declarations):
widl -I. --win64 -h -o DeckLinkAPI.h DeckLinkAPI.idl

# Generate DeckLinkAPI_i.c (CLSID and IID constant definitions):
widl -I. -I/mingw64/include --win64 -u -o DeckLinkAPI_i.c DeckLinkAPI.idl
```

The versioned IDL files (`DeckLinkAPI_v14_2_1.idl`, etc.) cannot be compiled standalone by widl because they reference types only available in the main IDL context. Since the main `DeckLinkAPI.h` already contains all versioned interfaces, create stub headers that point to it:

```bash
for f in DeckLinkAPI_v10_2.h DeckLinkAPI_v10_11.h DeckLinkAPI_v11_4.h \
          DeckLinkAPI_v11_5.h DeckLinkAPI_v11_5_1.h DeckLinkAPI_v11_6.h \
          DeckLinkAPI_v12_0.h DeckLinkAPI_v14_2_1.h DeckLinkAPI_v15_2.h; do
  printf '#pragma once\n#include "DeckLinkAPI.h"\n' > "$f"
done
```

#### 4. Write the Windows COM dispatch file

The SDK ships `DeckLinkAPIDispatch.cpp` for Linux/macOS which uses `dlopen`/`dlsym`. Windows uses COM instead — `CoCreateInstance` with CLSIDs registered by the Desktop Video driver.

Create `~/decklink-sdk/DeckLinkAPIDispatch.cpp` (see `build/windows/DeckLinkAPIDispatch.cpp` in this repo).

#### 5. Clone and configure ffmpeg

```bash
git clone --depth=1 https://github.com/FFmpeg/FFmpeg.git ~/ffmpeg-src
cd ~/ffmpeg-src

./configure \
  --prefix=/home/$USER/ffmpeg-out \
  --enable-gpl \
  --enable-nonfree \
  --enable-decklink \
  --enable-libx264 \
  --enable-libx265 \
  --enable-static \
  --disable-shared \
  --disable-debug \
  --disable-doc \
  --disable-ffplay \
  --disable-ffprobe \
  --extra-cflags="-I/home/$USER/decklink-sdk" \
  --extra-cxxflags="-I/home/$USER/decklink-sdk" \
  --extra-ldflags='-Wl,--start-group' \
  --extra-libs='-Wl,--end-group'
```

Verify DeckLink was picked up:
```bash
grep 'CONFIG_DECKLINK_INDEV' ffbuild/config.mak
# Should print: CONFIG_DECKLINK_INDEV=yes
```

The `--start-group`/`--end-group` linker flags resolve circular archive dependencies between `libavdevice` (which contains DeckLink code) and `libavcodec` (whose internal symbols DeckLink calls).

#### 6. Patch ffbuild/library.mak

MSYS2 sets `RESPONSE_FILES=yes` in `ffbuild/config.mak`, which makes the build write object file lists to a `.objs` response file then pass `@file` to `ar`. The original implementation uses `echo $^ > $@.objs` in a shell recipe. With ~1000 object files in libavcodec, the expanded command exceeds Windows' 32767-character `CreateProcess` limit — the echo fails silently and `ar` creates an empty archive.

**Fix:** replace `echo` with GNU Make's `$(file ...)` built-in, which writes to a file entirely within Make without spawning a shell process:

```bash
sed -i 's/$(Q)echo $^ > $@.objs/$(file > $@.objs,$^)/' ffbuild/library.mak
```

Why this works:
- `$(file > filename,text)` is a GNU Make 4.0+ built-in that writes `text` to `filename` directly — no process spawn, no command line length limit
- The call expands to an empty string, so the shell recipe line becomes a no-op
- MinGW's `ar @file` correctly reads space-separated object paths from the response file

#### 7. Build

```bash
make -j$(nproc)
make install

# Name the output binary ffmpeg-decklink.exe:
cp /home/$USER/ffmpeg-out/bin/ffmpeg.exe \
   /home/$USER/ffmpeg-out/bin/ffmpeg-decklink.exe
```

Verify DeckLink support in the built binary:
```bash
./ffmpeg-decklink.exe -f decklink -list_devices true -i "" 2>&1
# Should list connected DeckLink devices
```

#### 8. Bundle required DLLs and package

The binary dynamically links several MinGW runtime and codec DLLs not present on standard Windows. Identify them and bundle alongside the exe:

```bash
# List required DLLs:
objdump -p ffmpeg-decklink.exe | grep 'DLL Name'

# Copy MinGW DLLs (Windows system DLLs like KERNEL32.dll are already present):
DLLS=(
  libgcc_s_seh-1.dll libstdc++-6.dll libwinpthread-1.dll
  libx264-165.dll libx265-215.dll
  libbz2-1.dll libiconv-2.dll liblzma-5.dll
  zlib1.dll libva.dll libva_win32.dll
)
for dll in "${DLLS[@]}"; do cp /mingw64/bin/$dll .; done

zip ffmpeg-decklink-windows-amd64.zip ffmpeg-decklink.exe "${DLLS[@]}"
```

> **Note:** DLL names are versioned (e.g. `libx264-165.dll`). When the MinGW toolchain is updated, run `objdump -p` again to get the current names.

See `build/windows/build.sh` for a complete automated script.