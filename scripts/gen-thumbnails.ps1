# scripts/gen-thumbnails.ps1
# Generates 20px-wide JPEG thumbnails as base64 for blur-up placeholders.
# Output: scripts/blur-data.json -- map of { "html-src-attr": "data:image/jpeg;base64,..." }
Add-Type -AssemblyName System.Drawing

$projectRoot = Split-Path $PSScriptRoot -Parent

# Keys = exact src attribute values from index.html
# Values = actual relative file paths on disk
$srcToFile = [ordered]@{
  "Images/Our%20First%20time%20in%20your%20birthplace.jpeg" = "Images/Our First time in your birthplace.jpeg"
  "Images/Our%20first%20travel.jpeg"                        = "Images/Our first travel.jpeg"
  "Images/IMG_3982.JPG"                                     = "Images/IMG_3982.JPG"
  "Images/Anh gadaad.jpg"                                   = "Images/Anh gadaad.jpg"
  "Images/Borootoi odor.jpg"                                = "Images/Borootoi odor.jpg"
  "Images/Friend%201.jpg"                                   = "Images/Friend 1.jpg"
  "Images/Friend%202.jpg"                                   = "Images/Friend 2.jpg"
  "Images/Friend%203.jpg"                                   = "Images/Friend 3.jpg"
  "Images/Friend%204.jpeg"                                  = "Images/Friend 4.jpeg"
  "Images/Friend%205.jpeg"                                  = "Images/Friend 5.jpeg"
  "Images/Our official starting point.JPG"                  = "Images/Our official starting point.JPG"
  "Images/our first adventure.jpg"                          = "Images/our first adventure.jpg"
  "Images/When I Knew.JPG"                                  = "Images/When I Knew.JPG"
  "Images/IMG_8960.jpg"                                     = "Images/IMG_8960.jpg"
  "images/Right now.jpg"                                    = "Images/Right now.jpg"
}

# Add entries with Cyrillic/special characters using char codes to avoid encoding issues at save-time
# Mongolian: Хөгжилтэй мөч.jpg
$cyrKey1  = "Images/" + [char]0x0425 + [char]0x04E9 + [char]0x0433 + [char]0x0436 + [char]0x0438 + [char]0x043B + [char]0x0442 + [char]0x044D + [char]0x0439 + " " + [char]0x043C + [char]0x04E9 + [char]0x0447 + ".jpg"
$cyrVal1  = "Images/" + [char]0x0425 + [char]0x04E9 + [char]0x0433 + [char]0x0436 + [char]0x0438 + [char]0x043B + [char]0x0442 + [char]0x044D + [char]0x0439 + " " + [char]0x043C + [char]0x04E9 + [char]0x0447 + ".jpg"
$srcToFile[$cyrKey1] = $cyrVal1

# FullSizeRender.jpeg (trailing space in src attr)
$srcToFile["Images/FullSizeRender.jpeg "] = "Images/FullSizeRender.jpeg"

# Ээж.png -> URL-encoded key
$srcToFile["Images/%D0%AD%D1%8D%D0%B6.png"] = "Images/" + [char]0x042D + [char]0x044D + [char]0x0436 + ".png"

# Аав.png -> Cyrillic key
$cyrAavKey = "Images/" + [char]0x0410 + [char]0x0430 + [char]0x0432 + ".png"
$cyrAavVal = "Images/" + [char]0x0410 + [char]0x0430 + [char]0x0432 + ".png"
$srcToFile[$cyrAavKey] = $cyrAavVal

# Дүү.png -> URL-encoded key
$srcToFile["Images/%D0%94%D2%AF%D2%AF.png"] = "Images/" + [char]0x0414 + [char]0x04AF + [char]0x04AF + ".png"

# Backslash variant for IMG_8960
$srcToFile['Images\IMG_8960.jpg'] = "Images/IMG_8960.jpg"

$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
$encParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
$encParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
  [System.Drawing.Imaging.Encoder]::Quality, [long]60)

$blurData = [ordered]@{}

foreach ($entry in $srcToFile.GetEnumerator()) {
  $srcAttr  = $entry.Key
  $filePath = Join-Path $projectRoot $entry.Value

  if (-not (Test-Path $filePath)) {
    Write-Warning "MISSING: $filePath"
    continue
  }

  try {
    $img   = [System.Drawing.Image]::FromFile($filePath)
    $newW  = 20
    $newH  = [Math]::Max(1, [int]($newW * $img.Height / $img.Width))
    $thumb = New-Object System.Drawing.Bitmap($newW, $newH)
    $g     = [System.Drawing.Graphics]::FromImage($thumb)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($img, 0, 0, $newW, $newH)
    $g.Dispose()

    $ms     = New-Object System.IO.MemoryStream
    $thumb.Save($ms, $jpegCodec, $encParams)
    $base64 = [Convert]::ToBase64String($ms.ToArray())
    $blurData[$srcAttr] = "data:image/jpeg;base64," + $base64

    $img.Dispose(); $thumb.Dispose(); $ms.Dispose()
    Write-Host "OK $srcAttr"
  } catch {
    Write-Warning "FAILED ${filePath}: $_"
  }
}

$outPath = Join-Path $PSScriptRoot "blur-data.json"
$utf8    = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($outPath, ($blurData | ConvertTo-Json -Depth 2), $utf8)
Write-Host "Done -> scripts/blur-data.json ($($blurData.Count) entries)"