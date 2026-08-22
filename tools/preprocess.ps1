param(
    [string]$Source = "images",
    [string]$Dest = "images-prep",
    [int]$MaxSide = 2000,
    [int]$MinSide = 1000,
    [int]$Quality = 88,
    [int]$Strips = 0,
    [int]$Overlap = 32
)
# 简谱图片预处理: 统一缩放到适合视觉模型的分辨率, 输出 JPEG
# -Strips N: 同时把每张图切成 N 像素高的横条 (重叠 Overlap 像素), 存为 <名>_strip_XX.jpg
Add-Type -AssemblyName System.Drawing
$enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
$ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]$Quality)

function Save-Jpeg($img, $path) {
    $img.Save($path, $enc, $ep)
}

# 同步复制元数据 (song.json 等)
Get-ChildItem -Path $Source -Recurse -File -Include *.json, *.txt | ForEach-Object {
    $rel = $_.FullName.Substring((Resolve-Path $Source).Path.Length).TrimStart('\', '/')
    $out = Join-Path $Dest $rel
    New-Item -ItemType Directory -Path (Split-Path $out -Parent) -Force | Out-Null
    Copy-Item $_.FullName $out -Force
}

$files = Get-ChildItem -Path $Source -Recurse -File -Include *.jpg, *.jpeg, *.png, *.gif, *.webp
$count = 0
foreach ($f in $files) {
    $rel = $f.FullName.Substring((Resolve-Path $Source).Path.Length).TrimStart('\', '/')
    $base = [System.IO.Path]::GetFileNameWithoutExtension($rel)
    $out = Join-Path $Dest (Split-Path $rel -Parent)
    New-Item -ItemType Directory -Path $out -Force | Out-Null
    try {
        $img = [System.Drawing.Image]::FromFile($f.FullName)
        $w = $img.Width; $h = $img.Height
        $scale = 1.0
        if ([Math]::Max($w, $h) -gt $MaxSide) { $scale = $MaxSide / [Math]::Max($w, $h) }
        elseif ([Math]::Max($w, $h) -lt $MinSide) { $scale = $MinSide / [Math]::Max($w, $h) }
        if ($scale -ne 1.0) {
            $nw = [int][Math]::Round($w * $scale); $nh = [int][Math]::Round($h * $scale)
            $bmp = New-Object System.Drawing.Bitmap($nw, $nh)
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g.DrawImage($img, 0, 0, $nw, $nh)
            $g.Dispose()
            $img.Dispose()
            $img = $bmp
        }
        $fullPath = Join-Path $out ($base + ".jpg")
        Save-Jpeg $img $fullPath
        $count++

        if ($Strips -gt 0 -and $img.Height -gt $Strips) {
            $i = 0
            $y = 0
            while ($y -lt $img.Height) {
                $sh = [Math]::Min($Strips, $img.Height - $y)
                $crop = New-Object System.Drawing.Bitmap($img.Width, $sh)
                $g = [System.Drawing.Graphics]::FromImage($crop)
                $g.DrawImage($img, (New-Object System.Drawing.Rectangle(0, 0, $img.Width, $sh)),
                             (New-Object System.Drawing.Rectangle(0, $y, $img.Width, $sh)),
                             [System.Drawing.GraphicsUnit]::Pixel)
                $g.Dispose()
                $stripPath = Join-Path $out ($base + "_strip_{0:D2}.jpg" -f $i)
                Save-Jpeg $crop $stripPath
                $crop.Dispose()
                $i++
                $y += ($Strips - $Overlap)
            }
        }
        $img.Dispose()
    } catch {
        Write-Host "跳过 $($f.FullName): $($_.Exception.Message)"
    }
}
Write-Host "预处理完成: $count 张 -> $Dest" + $(if ($Strips -gt 0) { " (含横条切片)" } else { "" })

