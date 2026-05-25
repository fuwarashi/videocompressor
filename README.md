<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/12b309e6-6f48-40a3-86fe-99103b397b24" />VideoCompressor

A simple Windows GUI app that compresses videos to a target file size using FFmpeg two-pass encoding.

Requirements:
- ffmpeg and ffprobe installed and in PATH
- FFmpeg download: use "winget install ffmpeg" on command prompt or powershell.
- .NET Desktop Runtime 8 (x64)

Keep these files in the same folder:
- VideoCompressor.exe
- VideoCompressor.dll
- VideoCompressor.deps.json
- VideoCompressor.runtimeconfig.json

How to use:
1. Open VideoCompressor.exe
2. Select a video
3. Enter target size in MB
4. Click Start Compression

Output is saved as: <original_name>_compressed.mp4
