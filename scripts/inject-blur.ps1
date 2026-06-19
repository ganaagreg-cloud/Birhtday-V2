# scripts/inject-blur.ps1
# 1. Injects data-blur="<base64>" onto every <img> in index.html
# 2. Fixes two broken src paths: backslash and wrong case
# NOTE: injection runs BEFORE path fixes so keys match original HTML src attributes

$scriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$indexPath    = Join-Path (Join-Path $scriptDir "..") "index.html"
$blurDataPath = Join-Path $scriptDir "blur-data.json"

$utf8    = New-Object System.Text.UTF8Encoding($false)
$html    = [System.IO.File]::ReadAllText($indexPath, [System.Text.Encoding]::UTF8)
$rawJson = [System.IO.File]::ReadAllText($blurDataPath, [System.Text.Encoding]::UTF8)
$blurMap = $rawJson | ConvertFrom-Json

$injected = 0
foreach ($prop in $blurMap.PSObject.Properties) {
    $srcAttr  = $prop.Name
    $dataBlur = $prop.Value

    $escapedSrc = [Regex]::Escape($srcAttr)
    $pattern = '(<img\b(?![^>]*data-blur)[^>]*\bsrc="' + $escapedSrc + '"[^>]*?)(\s*>)'

    $testMatch = [Regex]::Match($html, $pattern)
    if ($testMatch.Success) {
        $replacement = $testMatch.Groups[1].Value + ' data-blur="' + $dataBlur + '"' + $testMatch.Groups[2].Value
        $html = $html.Substring(0, $testMatch.Index) + $replacement + $html.Substring($testMatch.Index + $testMatch.Length)
        $injected++
        Write-Host "Injected: $srcAttr"
    } else {
        Write-Warning "No match: $srcAttr"
    }
}

# Fix broken src paths AFTER injection (so original keys matched above)
$html = $html.Replace('src="Images\IMG_8960.jpg"', 'src="Images/IMG_8960.jpg"')
$html = $html.Replace('src="images/Right now.jpg"', 'src="Images/Right now.jpg"')
Write-Host "Fixed broken src paths"

[System.IO.File]::WriteAllText($indexPath, $html, $utf8)
$total = ($blurMap.PSObject.Properties | Measure-Object).Count
Write-Host "Done - injected $injected / $total images"
