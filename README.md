# ffmpeg-decklink

Pre-built ffmpeg binaries with Blackmagic DeckLink support, for use with [osc-record](https://github.com/danielbrodie/osc-record).

## Build configuration

```
--prefix=/opt/homebrew --enable-gpl --enable-nonfree --enable-decklink
--extra-cflags=-I/opt/homebrew/include --extra-cxxflags=-I/opt/homebrew/include
--extra-ldflags=-L/opt/homebrew/lib --enable-libx264 --enable-libx265
--enable-videotoolbox --enable-audiotoolbox
```

Built from ffmpeg git master (2026-03-13, commit 51606de).
DeckLink SDK: 15.3
