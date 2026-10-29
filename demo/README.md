# Demo video

How the demo video is made. Everything here is reproducible; only the screen recording itself is not committed.

## 1. Record

```sh
swift build -c release
swiftc -O demo/stage/stage.swift -o build/stage
build/stage build/layout.json &              # full-screen backdrop; click or Esc quits it
ffmpeg -f avfoundation -capture_cursor 0 -framerate 60 -pixel_format nv12 -i "<screen>:none" \
       -c:v h264_videotoolbox -b:v 45M -realtime 1 build/take.mp4 &
.build/release/HaloSearch --demo build/layout.json build/take-log.json
```

- `stage/` is a made-up travel article shown full screen, so nothing personal is recorded. It parks the pointer at
  the left edge (where it is cropped out) and writes where the photo and the text to scribble over are.
- `HaloSearch --demo` drives the real app — capture, overlay, Google searches, results panel — through the script in
  `Sources/HaloSearch/Diagnostics/DemoDirector.swift`, replaying strokes smoothly with a touch dot, and logs the time
  of every step. If Google shows its traffic check, it stops so the take can be redone later.
- List screens with `ffmpeg -f avfoundation -list_devices true -i ""`. Stop ffmpeg with Ctrl-C once the demo exits.

## 2. Edit

```sh
ffmpeg -i build/take.mp4 -vf "crop=iw-120:ih:60:0" -c:v libx264 -crf 14 -an demo/video/public/footage.mp4
cp build/take-log.json demo/video/src/take-log.json
cd demo/video && npm install && npm run render     # → out/halo-search-demo.mp4
```

The video is a [Remotion](https://www.remotion.dev) project. `src/timeline.ts` turns the director's log into the
edit: speed ramps while Google is thinking (badged on screen), camera moves and caption timings. Set
`RECORDING_OFFSET` to the gap between the start of the recording and the director's clock (find the frame where
the overlay dims the screen). `npm run studio` opens an interactive preview.

## Credits

The photo of the Eiffel Tower is by Benh LIEU SONG, released into the public domain
([Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Tour_Eiffel_Wikimedia_Commons_(cropped).jpg)).
The article, author and website on the stage are fictional.
