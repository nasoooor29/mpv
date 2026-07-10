param(
  [Parameter(Mandatory = $true)]
  [string]$Video
)

# strip the video from suffix and prefix " and '
$Video = $Video.Trim("'`"")

function To-Ms($t) {
  if ($t -match '(\d+):(\d+):(\d+)[,.](\d+)') {
    $ms = ($Matches[4] + "000").Substring(0, 3)
    return (([int]$Matches[1] * 3600 + [int]$Matches[2] * 60 + [int]$Matches[3]) * 1000 + [int]$ms)
  }
  throw "Bad time: $t"
}

function First-Sub-Time($file) {
  foreach ($l in Get-Content -LiteralPath $file -Encoding UTF8) {
    if ($l -match '^\s*(\d+:\d+:\d+[,\.]\d+)\s*-->') { return $Matches[1] }
    if ($l -match '^Dialogue:[^,]*,(\d+:\d+:\d+\.\d+),') { return $Matches[1] }
  }
  throw "No timing found in $file"
}

$videoItem = Get-Item -LiteralPath $Video
$dir = $videoItem.Directory.FullName
$base = [IO.Path]::GetFileNameWithoutExtension($videoItem.Name)

$subs = Get-ChildItem -LiteralPath $dir -File |
Where-Object { $_.Name -match '\.(srt|ass|ssa)$' }

$sub = Get-ChildItem -LiteralPath $dir -File |
Where-Object { $_.Name -match '\.(srt|ass|ssa)$' } |
Where-Object {
  $_.Name.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)
} |
Select-Object -First 1
if (-not $sub) {
  throw "No matching subtitle found beside video. Checked: $dir"
}

$tmp = Join-Path $env:TEMP ([guid]::NewGuid().ToString() + ".srt")

ffmpeg -y -loglevel error -i $videoItem.FullName -map 0:s:0 -frames:s 1 $tmp

$videoTime = First-Sub-Time $tmp
$extTime = First-Sub-Time $sub.FullName

$diffMs = (To-Ms $extTime) - (To-Ms $videoTime)

# "Video:    $($videoItem.Name)"
# "External: $($sub.Name)"
# "Video first sub:    $videoTime"
# "External first sub: $extTime"
# "Difference:         $diffMs ms"
# "ffmpeg offset fix:  $([math]::Round(-$diffMs / 1000, 3)) seconds"

Write-Output $([math]::Round(-$diffMs / 1000, 3))
Remove-Item $tmp -ErrorAction SilentlyContinue
