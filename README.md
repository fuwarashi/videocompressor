# VideoCompressor

Compresses a video file to a target size using FFmpeg two-pass encoding.

## Requirements

- FFmpeg installed and added to `PATH` (must include both `ffmpeg` and `ffprobe`)

## Run

- Keep these files together in the same folder:
  - `VideoCompressor.exe`
  - `VideoCompressor.dll`
  - `VideoCompressor.deps.json`
  - `VideoCompressor.runtimeconfig.json`
- Double-click `VideoCompressor.exe`
- Choose a video file
- Set target size in MB
- Click `Start Compression`

Output is saved as `<original_name>_compressed.mp4` by default.

## Notes

- This optimized build is framework-dependent (much smaller size).
- It requires .NET Desktop Runtime 8 on the target machine.
