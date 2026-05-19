# VideoCompressor

Compresses a video file to a target size using FFmpeg two-pass encoding.

## Requirements

- FFmpeg installed and added to `PATH` (must include both `ffmpeg` and `ffprobe`)

## Use The GUI (Recommended)

1. Double-click `VideoCompressorGUI.bat`
2. Choose a video file
3. Set target size in MB
4. Click `Compress`

The GUI shows live FFmpeg logs and saves output as `<original_name>_compressed.mp4` by default.

## Use The Script Window (CLI Prompt Style)

You can still use `VideoCompressor.bat`:

- Drag a video onto `VideoCompressor.bat`, or
- Open it first, then drag a video path into the window and press Enter
