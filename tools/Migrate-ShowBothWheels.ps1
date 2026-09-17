param(
    [Parameter(Mandatory=$true)][string]$ConfigPath,
    [switch]$CheckOnly
)
$ErrorActionPreference='Stop'
$resolved=(Resolve-Path -LiteralPath $ConfigPath).Path
$original=[IO.File]::ReadAllBytes($resolved)
$utf8=[Text.UTF8Encoding]::new($false,$true)
$text=$utf8.GetString($original)
$section=''
$generalCount=0
$values=@()
foreach($line in ($text -split '\r?\n')) {
    $line=$line.TrimStart([char]0xFEFF)
    if($line -match '^\s*\[([^\]]+)\]\s*$') {
        $section=$Matches[1]
        if($section -eq 'General') { $generalCount++ }
    } elseif($section -eq 'General' -and $line -match '^\s*ShowBothWheels\s*=\s*([^;#]*)(?:[;#].*)?$') {
        $values+= $Matches[1].Trim()
    }
}
if($generalCount -ne 1) { throw 'Expected exactly one [General] section; configuration was not changed.' }
if($values.Count -gt 1) { throw 'Duplicate ShowBothWheels keys; configuration was not changed.' }
if($values.Count -eq 1) {
    if($values[0] -notin @('0','1')) { throw 'ShowBothWheels must be 0 or 1; configuration was not changed.' }
    Write-Output "No migration needed: existing ShowBothWheels=$($values[0]) preserved."
    return
}
$header=[regex]::Match($text,'(?m)^(?:\uFEFF)?[ \t]*\[General\][ \t]*(?:\r?\n|$)')
if(-not $header.Success) { throw 'Cannot locate [General] insertion point; configuration was not changed.' }
$eol=if($text.Contains("`r`n")) { "`r`n" } else { "`n" }
$prefix=if($header.Value.EndsWith("`n")) { '' } else { $eol }
$updated=$text.Insert($header.Index+$header.Length,$prefix+'ShowBothWheels=1'+$eol)
if($CheckOnly) { Write-Output 'Migration required: insert ShowBothWheels=1 in [General]. No file changed.'; return }
$token=[Guid]::NewGuid().ToString('N')
$backup=$resolved+'.before-0.3.30.'+$token+'.bak'
$stream=[IO.File]::Open($resolved,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
try {
    $current=[byte[]]::new($stream.Length)
    $read=$stream.Read($current,0,$current.Length)
    if($read -ne $current.Length -or [Convert]::ToBase64String($current) -ne [Convert]::ToBase64String($original)) {
        throw 'Configuration changed during migration; refusing replacement.'
    }
    $saved=[IO.File]::Open($backup,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try { $saved.Write($original,0,$original.Length); $saved.Flush($true) } finally { $saved.Dispose() }
    $bytes=$utf8.GetBytes($updated)
    try {
        $stream.Position=0; $stream.Write($bytes,0,$bytes.Length); $stream.SetLength($bytes.Length); $stream.Flush($true)
    } catch {
        $stream.Position=0; $stream.Write($original,0,$original.Length); $stream.SetLength($original.Length); $stream.Flush($true)
        throw
    }
    Write-Output "Inserted ShowBothWheels=1; original bytes backed up to $backup"
} finally {
    $stream.Dispose()
}
