#!/usr/bin/env bash
# build/windows/build.sh
# Full automated Windows build of ffmpeg with DeckLink support.
# Run this from an MSYS2 MinGW64 shell (not the MSYS shell).
#
# Prerequisites (install once):
#   winget install MSYS2.MSYS2
#   # Then open "MSYS2 MinGW64" from the Start menu and run:
#   pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-x264 mingw-w64-x86_64-x265 \
#             mingw-w64-x86_64-binutils diffutils make zip
#   ln -sf /mingw64/bin/mingw32-make.exe /usr/bin/make
#
# DeckLink SDK 15.3:
#   Download from https://www.blackmagicdesign.com/developer
#   Extract the zip so that DeckLinkAPI.idl is at ~/decklink-sdk/DeckLinkAPI.idl

set -euo pipefail

DECKLINK_SDK="${HOME}/decklink-sdk"
FFMPEG_SRC="${HOME}/ffmpeg-src"
FFMPEG_OUT="${HOME}/ffmpeg-out"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# 1. Validate DeckLink SDK
# ---------------------------------------------------------------------------
if [[ ! -f "${DECKLINK_SDK}/DeckLinkAPI.idl" ]]; then
  echo "ERROR: DeckLink SDK not found at ${DECKLINK_SDK}/DeckLinkAPI.idl"
  echo "Extract the Blackmagic DeckLink SDK 15.3 zip to ~/decklink-sdk/ and re-run."
  exit 1
fi

echo "==> Step 1: Generating DeckLink headers from IDL"
cd "${DECKLINK_SDK}"

widl -I. --win64 -h -o DeckLinkAPI.h DeckLinkAPI.idl
widl -I. -I/mingw64/include --win64 -u -o DeckLinkAPI_i.c DeckLinkAPI.idl

# Stub headers for versioned IDLs (all interfaces are already in DeckLinkAPI.h)
for f in DeckLinkAPI_v10_2.h DeckLinkAPI_v10_11.h DeckLinkAPI_v11_4.h \
          DeckLinkAPI_v11_5.h DeckLinkAPI_v11_5_1.h DeckLinkAPI_v11_6.h \
          DeckLinkAPI_v12_0.h DeckLinkAPI_v14_2_1.h DeckLinkAPI_v15_2.h; do
  printf "#pragma once\n#include \"DeckLinkAPI.h\"\n" > "${DECKLINK_SDK}/${f}"
done

echo "==> Step 2: Installing Windows COM dispatch file"
cp "${SCRIPT_DIR}/DeckLinkAPIDispatch.cpp" "${DECKLINK_SDK}/DeckLinkAPIDispatch.cpp"

# ---------------------------------------------------------------------------
# 3. Clone FFmpeg
# ---------------------------------------------------------------------------
echo "==> Step 3: Cloning FFmpeg"
if [[ -d "${FFMPEG_SRC}" ]]; then
  echo "    ${FFMPEG_SRC} already exists — skipping clone"
else
  git clone --depth=1 https://github.com/FFmpeg/FFmpeg.git "${FFMPEG_SRC}"
fi

# ---------------------------------------------------------------------------
# 4. Configure
# ---------------------------------------------------------------------------
echo "==> Step 4: Configuring FFmpeg"
cd "${FFMPEG_SRC}"

./configure \
  --prefix="${FFMPEG_OUT}" \
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
  --extra-cflags="-I${DECKLINK_SDK}" \
  --extra-cxxflags="-I${DECKLINK_SDK}" \
  --extra-ldflags="-Wl,--start-group" \
  --extra-libs="-Wl,--end-group"

# Verify DeckLink was detected
if ! grep -q "CONFIG_DECKLINK_INDEV=yes" ffbuild/config.mak; then
  echo "ERROR: DeckLink was not detected by configure. Check that DeckLinkAPI.h is in ${DECKLINK_SDK}."
  exit 1
fi
echo "    DeckLink indev: OK"

# ---------------------------------------------------------------------------
# 5. Patch ffbuild/library.mak — ar response file fix
# ---------------------------------------------------------------------------
# On Windows, RESPONSE_FILES=yes causes "echo $^ > $@.objs" which exceeds the
# 32767-char CreateProcess command line limit with ~1000 .o files.
# Replace with GNU Make's $(file ...) built-in, which writes directly from
# Make without spawning a shell.
echo "==> Step 5: Patching ffbuild/library.mak for Windows ar response file"
sed -i 's/$(Q)echo $^ > $@.objs/$(file > $@.objs,$^)/' ffbuild/library.mak

# ---------------------------------------------------------------------------
# 6. Build
# ---------------------------------------------------------------------------
echo "==> Step 6: Building (this will take a while)"
make -j"$(nproc)"
make install

cp "${FFMPEG_OUT}/bin/ffmpeg.exe" "${FFMPEG_OUT}/bin/ffmpeg-decklink.exe"
echo "    Binary: ${FFMPEG_OUT}/bin/ffmpeg-decklink.exe"

# ---------------------------------------------------------------------------
# 7. Bundle DLLs and create zip
# ---------------------------------------------------------------------------
echo "==> Step 7: Bundling DLLs"

# Discover required DLLs from the binary (skip Windows system DLLs)
SYSTEM_DLLS="KERNEL32.DLL|USER32.DLL|ADVAPI32.DLL|SHELL32.DLL|OLE32.DLL|OLEAUT32.DLL|BCRYPT.DLL|NTDLL.DLL|SECUR32.DLL|CRYPT32.DLL|WS2_32.DLL|IPHLPAPI.DLL|DXVA2.DLL|D3D11.DLL|WINMM.DLL|AVRT.DLL|MFPLAT.DLL|MFUUID.DLL|STRMIIDS.DLL"

mapfile -t REQUIRED_DLLS < <(
  objdump -p "${FFMPEG_OUT}/bin/ffmpeg-decklink.exe" \
    | grep "DLL Name:" \
    | awk "{print \$3}" \
    | grep -viE "^(${SYSTEM_DLLS})$"
)

if [[ ${#REQUIRED_DLLS[@]} -eq 0 ]]; then
  echo "    No bundleable DLLs found — binary may be fully static or objdump failed."
else
  echo "    DLLs to bundle: ${REQUIRED_DLLS[*]}"
fi

STAGE_DIR="${HOME}/ffmpeg-release-windows"
rm -rf "${STAGE_DIR}"
mkdir -p "${STAGE_DIR}"
cp "${FFMPEG_OUT}/bin/ffmpeg-decklink.exe" "${STAGE_DIR}/"

MISSING=()
for dll in "${REQUIRED_DLLS[@]}"; do
  src="/mingw64/bin/${dll}"
  if [[ -f "${src}" ]]; then
    cp "${src}" "${STAGE_DIR}/"
  else
    MISSING+=("${dll}")
  fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "WARNING: Could not find these DLLs in /mingw64/bin — bundle them manually:"
  printf "  %s\n" "${MISSING[@]}"
fi

OUTPUT_ZIP="${HOME}/ffmpeg-decklink-windows-amd64.zip"
cd "${STAGE_DIR}"
zip -j "${OUTPUT_ZIP}" ./*

echo ""
echo "==> Done!"
echo "    Output zip: ${OUTPUT_ZIP}"
echo "    Contents:"
unzip -l "${OUTPUT_ZIP}"
