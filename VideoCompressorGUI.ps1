Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class NativeIcon {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern bool DestroyIcon(IntPtr handle);
}
"@

function Normalize-UserPath {
    param([string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return ""
    }

    $clean = $PathValue.Trim()
    if ($clean.Length -ge 2 -and $clean.StartsWith('"') -and $clean.EndsWith('"')) {
        $clean = $clean.Substring(1, $clean.Length - 2)
    }

    return $clean
}

function Get-DefaultOutputPath {
    param([string]$InputPath)

    if ([string]::IsNullOrWhiteSpace($InputPath)) {
        return ""
    }

    try {
        $fullPath = [System.IO.Path]::GetFullPath($InputPath)
        $directory = [System.IO.Path]::GetDirectoryName($fullPath)
        $name = [System.IO.Path]::GetFileNameWithoutExtension($fullPath)
        return [System.IO.Path]::Combine($directory, "${name}_compressed.mp4")
    } catch {
        return ""
    }
}

function Get-ToolPathOrNull {
    param([string]$ToolName)
    $cmd = Get-Command -Name $ToolName -ErrorAction SilentlyContinue
    if ($null -eq $cmd) {
        return $null
    }
    return $cmd.Source
}

function Set-FormIconFromPath {
    param(
        [System.Windows.Forms.Form]$TargetForm,
        [string]$IconPath
    )

    if ([string]::IsNullOrWhiteSpace($IconPath) -or -not (Test-Path -LiteralPath $IconPath -PathType Leaf)) {
        return $false
    }

    try {
        $extension = [System.IO.Path]::GetExtension($IconPath).ToLowerInvariant()
        if ($extension -eq ".ico") {
            $iconFromFile = New-Object System.Drawing.Icon($IconPath)
            $TargetForm.Icon = $iconFromFile
            return $true
        }

        $image = [System.Drawing.Image]::FromFile($IconPath)
        $iconBitmap = New-Object System.Drawing.Bitmap($image, (New-Object System.Drawing.Size(64, 64)))
        $hIcon = $iconBitmap.GetHicon()
        $managedIcon = [System.Drawing.Icon]::FromHandle($hIcon)
        $TargetForm.Icon = [System.Drawing.Icon]::FromHandle($managedIcon.Handle)
        [NativeIcon]::DestroyIcon($hIcon) | Out-Null
        $iconBitmap.Dispose()
        $image.Dispose()
        return $true
    } catch {
        return $false
    }
}

$ffmpegPath = Get-ToolPathOrNull -ToolName "ffmpeg"
$ffprobePath = Get-ToolPathOrNull -ToolName "ffprobe"
if ($null -eq $ffmpegPath -or $null -eq $ffprobePath) {
    [System.Windows.Forms.MessageBox]::Show(
        "FFmpeg and ffprobe must be installed and available in PATH.",
        "Missing Requirement",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}

$script:colorBackground = [System.Drawing.Color]::FromArgb(16, 20, 26)
$script:colorSurface = [System.Drawing.Color]::FromArgb(26, 32, 41)
$script:colorSurfaceAlt = [System.Drawing.Color]::FromArgb(31, 39, 50)
$script:colorBorder = [System.Drawing.Color]::FromArgb(51, 60, 74)
$script:colorText = [System.Drawing.Color]::FromArgb(234, 239, 246)
$script:colorTextMuted = [System.Drawing.Color]::FromArgb(160, 173, 191)
$script:colorAccent = [System.Drawing.Color]::FromArgb(88, 166, 255)
$script:colorSuccess = [System.Drawing.Color]::FromArgb(63, 185, 80)
$script:colorDanger = [System.Drawing.Color]::FromArgb(248, 81, 73)

function New-StyledButton {
    param(
        [string]$Text,
        [bool]$Primary = $false
    )

    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.FlatStyle = "Flat"
    $button.FlatAppearance.BorderSize = 1
    $button.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(45, 54, 68)
    $button.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(52, 62, 79)
    $button.ForeColor = $script:colorText
    $button.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand

    if ($Primary) {
        $button.BackColor = $script:colorAccent
        $button.ForeColor = [System.Drawing.Color]::FromArgb(12, 22, 34)
        $button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(126, 189, 255)
        $button.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(113, 183, 255)
        $button.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(74, 152, 247)
    } else {
        $button.BackColor = $script:colorSurfaceAlt
        $button.FlatAppearance.BorderColor = $script:colorBorder
    }

    return $button
}

function Set-InputTheme {
    param([System.Windows.Forms.Control]$Control)
    $Control.BackColor = [System.Drawing.Color]::FromArgb(15, 20, 28)
    $Control.ForeColor = $script:colorText
    $Control.Font = New-Object System.Drawing.Font("Segoe UI", 9)
}

function Set-TextboxPlaceholderIfSupported {
    param(
        [System.Windows.Forms.TextBox]$TextBox,
        [string]$PlaceholderText
    )

    $placeholderProperty = $TextBox.GetType().GetProperty("PlaceholderText")
    if ($null -ne $placeholderProperty) {
        $TextBox.PlaceholderText = $PlaceholderText
    }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Video Compressor"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(900, 690)
$form.MinimumSize = New-Object System.Drawing.Size(860, 630)
$form.BackColor = $script:colorBackground
$form.ForeColor = $script:colorText
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.AllowDrop = $true

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$customIconCandidates = @(
    [System.IO.Path]::Combine($scriptDir, "app-icon.ico"),
    [System.IO.Path]::Combine($scriptDir, "appicon.ico"),
    [System.IO.Path]::Combine($scriptDir, "app-icon.png"),
    [System.IO.Path]::Combine($scriptDir, "appicon.png"),
    [System.IO.Path]::Combine($scriptDir, "app-icon.jpg"),
    [System.IO.Path]::Combine($scriptDir, "appicon.jpg"),
    [System.IO.Path]::Combine($scriptDir, "app-icon.jpeg")
    [System.IO.Path]::Combine($scriptDir, "appicon.jpeg")
)
foreach ($candidate in $customIconCandidates) {
    if (Set-FormIconFromPath -TargetForm $form -IconPath $candidate) {
        break
    }
}

$panelHeader = New-Object System.Windows.Forms.Panel
$panelHeader.Dock = "Top"
$panelHeader.Height = 86
$panelHeader.BackColor = $script:colorSurface

$labelTitle = New-Object System.Windows.Forms.Label
$labelTitle.Text = "Video Compressor"
$labelTitle.Location = New-Object System.Drawing.Point(18, 14)
$labelTitle.Size = New-Object System.Drawing.Size(400, 30)
$labelTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 16)
$labelTitle.ForeColor = $script:colorText

$labelSubtitle = New-Object System.Windows.Forms.Label
$labelSubtitle.Text = "Two-pass FFmpeg encoding with target file-size control."
$labelSubtitle.Location = New-Object System.Drawing.Point(20, 49)
$labelSubtitle.Size = New-Object System.Drawing.Size(540, 20)
$labelSubtitle.ForeColor = $script:colorTextMuted
$labelSubtitle.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)

$panelHeader.Controls.AddRange(@($labelTitle, $labelSubtitle))

$panelMain = New-Object System.Windows.Forms.Panel
$panelMain.Dock = "Fill"
$panelMain.Padding = New-Object System.Windows.Forms.Padding(16)
$panelMain.AllowDrop = $true

$panelSettings = New-Object System.Windows.Forms.Panel
$panelSettings.Dock = "Top"
$panelSettings.Height = 212
$panelSettings.BackColor = $script:colorSurface
$panelSettings.BorderStyle = "FixedSingle"
$panelSettings.Padding = New-Object System.Windows.Forms.Padding(14)
$panelSettings.AllowDrop = $true

$labelInput = New-Object System.Windows.Forms.Label
$labelInput.Text = "Video File"
$labelInput.Location = New-Object System.Drawing.Point(14, 18)
$labelInput.Size = New-Object System.Drawing.Size(120, 21)
$labelInput.ForeColor = $script:colorTextMuted

$txtInput = New-Object System.Windows.Forms.TextBox
$txtInput.Location = New-Object System.Drawing.Point(140, 14)
$txtInput.Size = New-Object System.Drawing.Size(600, 25)
$txtInput.Anchor = "Top, Left, Right"
Set-InputTheme -Control $txtInput
Set-TextboxPlaceholderIfSupported -TextBox $txtInput -PlaceholderText "Choose a video file or drop one onto this window"

$btnBrowseInput = New-StyledButton -Text "Browse"
$btnBrowseInput.Location = New-Object System.Drawing.Point(747, 12)
$btnBrowseInput.Size = New-Object System.Drawing.Size(105, 29)
$btnBrowseInput.Anchor = "Top, Right"

$labelDropHint = New-Object System.Windows.Forms.Label
$labelDropHint.Text = "Tip: you can drag a video file anywhere onto this app."
$labelDropHint.Location = New-Object System.Drawing.Point(140, 44)
$labelDropHint.Size = New-Object System.Drawing.Size(520, 18)
$labelDropHint.ForeColor = $script:colorTextMuted

$labelTarget = New-Object System.Windows.Forms.Label
$labelTarget.Text = "Target Size (MB)"
$labelTarget.Location = New-Object System.Drawing.Point(14, 79)
$labelTarget.Size = New-Object System.Drawing.Size(120, 21)
$labelTarget.ForeColor = $script:colorTextMuted

$numTargetMb = New-Object System.Windows.Forms.NumericUpDown
$numTargetMb.Location = New-Object System.Drawing.Point(140, 75)
$numTargetMb.Size = New-Object System.Drawing.Size(130, 25)
$numTargetMb.Minimum = 1
$numTargetMb.Maximum = 50000
$numTargetMb.Value = 25
$numTargetMb.BackColor = [System.Drawing.Color]::FromArgb(15, 20, 28)
$numTargetMb.ForeColor = $script:colorText
$numTargetMb.BorderStyle = "FixedSingle"

$labelTargetHint = New-Object System.Windows.Forms.Label
$labelTargetHint.Text = "Start with 8 MB, 25 MB, or 50 MB depending on your sharing limit."
$labelTargetHint.Location = New-Object System.Drawing.Point(281, 79)
$labelTargetHint.Size = New-Object System.Drawing.Size(575, 21)
$labelTargetHint.ForeColor = $script:colorTextMuted

$labelOutput = New-Object System.Windows.Forms.Label
$labelOutput.Text = "Output File"
$labelOutput.Location = New-Object System.Drawing.Point(14, 118)
$labelOutput.Size = New-Object System.Drawing.Size(120, 21)
$labelOutput.ForeColor = $script:colorTextMuted

$txtOutput = New-Object System.Windows.Forms.TextBox
$txtOutput.Location = New-Object System.Drawing.Point(140, 114)
$txtOutput.Size = New-Object System.Drawing.Size(600, 25)
$txtOutput.Anchor = "Top, Left, Right"
Set-InputTheme -Control $txtOutput
Set-TextboxPlaceholderIfSupported -TextBox $txtOutput -PlaceholderText "Output path (auto-filled if blank)"

$btnBrowseOutput = New-StyledButton -Text "Save As"
$btnBrowseOutput.Location = New-Object System.Drawing.Point(747, 112)
$btnBrowseOutput.Size = New-Object System.Drawing.Size(105, 29)
$btnBrowseOutput.Anchor = "Top, Right"

$btnCompress = New-StyledButton -Text "Start Compression" -Primary $true
$btnCompress.Location = New-Object System.Drawing.Point(14, 159)
$btnCompress.Size = New-Object System.Drawing.Size(165, 36)

$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Location = New-Object System.Drawing.Point(188, 166)
$progress.Size = New-Object System.Drawing.Size(440, 22)
$progress.Anchor = "Top, Left, Right"
$progress.Style = "Marquee"
$progress.Visible = $false

$labelStatus = New-Object System.Windows.Forms.Label
$labelStatus.Text = "Ready"
$labelStatus.Location = New-Object System.Drawing.Point(638, 166)
$labelStatus.Size = New-Object System.Drawing.Size(214, 23)
$labelStatus.Anchor = "Top, Right"
$labelStatus.TextAlign = "MiddleRight"
$labelStatus.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
$labelStatus.ForeColor = $script:colorSuccess

$panelSettings.Controls.AddRange(@(
    $labelInput, $txtInput, $btnBrowseInput, $labelDropHint,
    $labelTarget, $numTargetMb, $labelTargetHint,
    $labelOutput, $txtOutput, $btnBrowseOutput,
    $btnCompress, $progress, $labelStatus
))

$panelLog = New-Object System.Windows.Forms.Panel
$panelLog.Dock = "Fill"
$panelLog.BackColor = $script:colorSurface
$panelLog.BorderStyle = "FixedSingle"
$panelLog.Padding = New-Object System.Windows.Forms.Padding(12)

$labelLogTitle = New-Object System.Windows.Forms.Label
$labelLogTitle.Text = "Encoding Log"
$labelLogTitle.Dock = "Top"
$labelLogTitle.Height = 22
$labelLogTitle.ForeColor = $script:colorTextMuted
$labelLogTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Dock = "Fill"
$txtLog.Multiline = $true
$txtLog.ReadOnly = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 9.5)
$txtLog.BackColor = [System.Drawing.Color]::FromArgb(15, 20, 28)
$txtLog.ForeColor = $script:colorText
$txtLog.BorderStyle = "FixedSingle"

$panelLog.Controls.Add($txtLog)
$panelLog.Controls.Add($labelLogTitle)

$panelMain.Controls.Add($panelLog)
$panelMain.Controls.Add($panelSettings)

$form.Controls.Add($panelMain)
$form.Controls.Add($panelHeader)

$tooltips = New-Object System.Windows.Forms.ToolTip
$tooltips.BackColor = [System.Drawing.Color]::FromArgb(24, 30, 39)
$tooltips.ForeColor = $script:colorText
$tooltips.SetToolTip($btnBrowseInput, "Select input video file")
$tooltips.SetToolTip($numTargetMb, "Desired output file size in MB")
$tooltips.SetToolTip($btnBrowseOutput, "Choose output file location")
$tooltips.SetToolTip($btnCompress, "Start two-pass encoding")

function Add-LogLine {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return
    }
    $txtLog.AppendText($Text + [Environment]::NewLine)
    $txtLog.SelectionStart = $txtLog.TextLength
    $txtLog.ScrollToCaret()
}

$script:lastAutoOutput = ""

function Set-Status {
    param(
        [string]$Text,
        [System.Drawing.Color]$Color
    )
    $labelStatus.Text = $Text
    $labelStatus.ForeColor = $Color
}

function Update-SelectedInput {
    param([string]$PathValue)

    $normalizedInput = Normalize-UserPath -PathValue $PathValue
    if ([string]::IsNullOrWhiteSpace($normalizedInput)) {
        return
    }

    $previousOutput = Normalize-UserPath -PathValue $txtOutput.Text
    $txtInput.Text = $normalizedInput
    $suggestedOutput = Get-DefaultOutputPath -InputPath $normalizedInput

    if ([string]::IsNullOrWhiteSpace($previousOutput) -or $previousOutput -eq $script:lastAutoOutput) {
        $txtOutput.Text = $suggestedOutput
        $script:lastAutoOutput = $suggestedOutput
    }

    Set-Status -Text "Ready" -Color $script:colorSuccess
}

function Set-UiBusy {
    param([bool]$Busy)
    $btnBrowseInput.Enabled = -not $Busy
    $btnBrowseOutput.Enabled = -not $Busy
    $txtInput.Enabled = -not $Busy
    $txtOutput.Enabled = -not $Busy
    $numTargetMb.Enabled = -not $Busy
    $btnCompress.Enabled = -not $Busy
    $progress.Visible = $Busy
    if ($Busy) {
        Set-Status -Text "Working..." -Color $script:colorAccent
    }
}

$script:encodeJob = $null
$jobTimer = New-Object System.Windows.Forms.Timer
$jobTimer.Interval = 300

$jobTimer.Add_Tick({
    if ($null -eq $script:encodeJob) {
        return
    }

    $lines = Receive-Job -Job $script:encodeJob -ErrorAction SilentlyContinue
    foreach ($line in $lines) {
        Add-LogLine $line
    }

    if ($script:encodeJob.State -notin @("Completed", "Failed", "Stopped")) {
        return
    }

    $jobTimer.Stop()

    $remaining = Receive-Job -Job $script:encodeJob -ErrorAction SilentlyContinue
    foreach ($line in $remaining) {
        Add-LogLine $line
    }

    if ($script:encodeJob.State -eq "Completed") {
        Add-LogLine ""
        Add-LogLine "DONE: Output saved to $($txtOutput.Text)"
        Set-Status -Text "Done" -Color $script:colorSuccess
        [System.Windows.Forms.MessageBox]::Show(
            "Compression complete.",
            "Video Compressor",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    } else {
        $reason = $script:encodeJob.ChildJobs[0].JobStateInfo.Reason
        if ($null -ne $reason) {
            Add-LogLine "ERROR: $($reason.Message)"
        }
        foreach ($jobError in $script:encodeJob.ChildJobs[0].Error) {
            Add-LogLine "ERROR: $jobError"
        }
        Set-Status -Text "Failed" -Color $script:colorDanger
        [System.Windows.Forms.MessageBox]::Show(
            "Compression failed. See the log for details.",
            "Video Compressor",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }

    Remove-Job -Job $script:encodeJob -Force -ErrorAction SilentlyContinue
    $script:encodeJob = $null
    Set-UiBusy -Busy $false
})

$btnBrowseInput.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "Video Files|*.mp4;*.mov;*.mkv;*.avi;*.wmv;*.webm;*.m4v|All Files|*.*"
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        Update-SelectedInput -PathValue $dialog.FileName
    }
})

$btnBrowseOutput.Add_Click({
    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $dialog.Filter = "MP4 Video|*.mp4|All Files|*.*"
    $dialog.DefaultExt = "mp4"
    $currentOutput = Normalize-UserPath -PathValue $txtOutput.Text
    if (-not [string]::IsNullOrWhiteSpace($currentOutput)) {
        try {
            $dialog.InitialDirectory = [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($currentOutput))
            $dialog.FileName = [System.IO.Path]::GetFileName($currentOutput)
        } catch {
        }
    }
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtOutput.Text = $dialog.FileName
        $script:lastAutoOutput = ""
        Set-Status -Text "Ready" -Color $script:colorSuccess
    }
})

$dropEnterHandler = {
    param($sender, $e)
    if ($e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
        $e.Effect = [System.Windows.Forms.DragDropEffects]::Copy
    } else {
        $e.Effect = [System.Windows.Forms.DragDropEffects]::None
    }
}

$dropHandler = {
    param($sender, $e)
    if (-not $e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
        return
    }

    $files = $e.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop)
    if ($null -eq $files -or $files.Count -eq 0) {
        return
    }

    Update-SelectedInput -PathValue $files[0]
}

$form.Add_DragEnter($dropEnterHandler)
$form.Add_DragDrop($dropHandler)
$panelMain.Add_DragEnter($dropEnterHandler)
$panelMain.Add_DragDrop($dropHandler)
$panelSettings.Add_DragEnter($dropEnterHandler)
$panelSettings.Add_DragDrop($dropHandler)
$txtInput.AllowDrop = $true
$txtInput.Add_DragEnter($dropEnterHandler)
$txtInput.Add_DragDrop($dropHandler)

$btnCompress.Add_Click({
    if ($null -ne $script:encodeJob) {
        return
    }

    $inputPath = Normalize-UserPath -PathValue $txtInput.Text
    $outputPath = Normalize-UserPath -PathValue $txtOutput.Text
    $targetMb = [int]$numTargetMb.Value

    if ([string]::IsNullOrWhiteSpace($inputPath)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Choose a video file first.",
            "Video Compressor",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return
    }

    if (-not (Test-Path -LiteralPath $inputPath -PathType Leaf)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Input file not found.",
            "Video Compressor",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return
    }

    if ([string]::IsNullOrWhiteSpace($outputPath)) {
        $outputPath = Get-DefaultOutputPath -InputPath $inputPath
        $txtOutput.Text = $outputPath
        $script:lastAutoOutput = $outputPath
    }

    if ([string]::IsNullOrWhiteSpace($outputPath)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Could not determine output file path.",
            "Video Compressor",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return
    }

    $durationRaw = & ffprobe -v error -show_entries format=duration -of "default=noprint_wrappers=1:nokey=1" "$inputPath" 2>$null
    $durationText = @($durationRaw) |
        ForEach-Object { $_.ToString().Trim() } |
        Where-Object { $_ -ne "" } |
        Select-Object -First 1

    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($durationText)) {
        [System.Windows.Forms.MessageBox]::Show(
            "ffprobe could not read the video duration.",
            "Video Compressor",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return
    }
    $durationSeconds = 0.0
    $parsed = [double]::TryParse(
        $durationText,
        [System.Globalization.NumberStyles]::Float,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [ref]$durationSeconds
    )

    if (-not $parsed) {
        [System.Windows.Forms.MessageBox]::Show(
            "Invalid duration returned by ffprobe.",
            "Video Compressor",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return
    }

    $durationForMath = [Math]::Max($durationSeconds, 1.0)
    $totalBitrate = [int][Math]::Floor(($targetMb * 8192.0 * 95.0 / 100.0) / $durationForMath)
    $videoBitrate = [Math]::Max($totalBitrate - 128, 100)
    $workingDir = [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($outputPath))

    $txtLog.Clear()
    Add-LogLine "Input : $inputPath"
    Add-LogLine "Output: $outputPath"
    Add-LogLine "Target: $targetMb MB"
    Add-LogLine ("Duration (s): " + [Math]::Round($durationSeconds, 2))
    Add-LogLine "Video Bitrate: ${videoBitrate}k"
    Add-LogLine ""

    Set-Status -Text "Starting..." -Color $script:colorAccent
    Set-UiBusy -Busy $true

    $script:encodeJob = Start-Job -ScriptBlock {
        param(
            [string]$InputPath,
            [string]$OutputPath,
            [int]$VideoBitrate,
            [string]$RunDirectory
        )

        Set-Location -LiteralPath $RunDirectory

        function Invoke-FfmpegStep {
            param(
                [string]$Title,
                [string[]]$FfmpegArgs
            )

            Write-Output ">>> $Title"
            & ffmpeg @FfmpegArgs 2>&1 | ForEach-Object {
                if ($null -ne $_) {
                    $_.ToString()
                }
            }
            if ($LASTEXITCODE -ne 0) {
                throw "$Title failed with exit code $LASTEXITCODE."
            }
            Write-Output ""
        }

        $bitrateK = "${VideoBitrate}k"

        $pass1Args = @(
            "-y", "-i", $InputPath,
            "-c:v", "libx264",
            "-b:v", $bitrateK,
            "-pass", "1",
            "-an",
            "-f", "mp4",
            "NUL"
        )

        $pass2Args = @(
            "-y", "-i", $InputPath,
            "-c:v", "libx264",
            "-b:v", $bitrateK,
            "-pass", "2",
            "-c:a", "aac",
            "-b:a", "128k",
            $OutputPath
        )

        Invoke-FfmpegStep -Title "Pass 1 (Analysis)" -FfmpegArgs $pass1Args
        Invoke-FfmpegStep -Title "Pass 2 (Encoding)" -FfmpegArgs $pass2Args

        Remove-Item -LiteralPath "ffmpeg2pass-0.log", "ffmpeg2pass-0.log.mbtree" -ErrorAction SilentlyContinue
    } -ArgumentList $inputPath, $outputPath, $videoBitrate, $workingDir

    $jobTimer.Start()
})

$form.Add_FormClosing({
    if ($null -ne $script:encodeJob -and $script:encodeJob.State -eq "Running") {
        Stop-Job -Job $script:encodeJob -Force -ErrorAction SilentlyContinue
        Remove-Job -Job $script:encodeJob -Force -ErrorAction SilentlyContinue
    }
})

[void]$form.ShowDialog()
