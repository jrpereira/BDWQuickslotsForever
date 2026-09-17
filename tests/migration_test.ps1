$ErrorActionPreference = 'Stop'
$migration = Join-Path $PSScriptRoot '../tools/Migrate-ShowBothWheels.ps1'
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('bdw-migration-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
$utf8 = [Text.UTF8Encoding]::new($false)
function Assert-Equal($Actual, $Expected, $Message) {
    if ($Actual -cne $Expected) { throw $Message }
}
try {
    foreach ($eol in @("`n", "`r`n")) {
        $path = Join-Path $fixtureRoot ([Guid]::NewGuid().ToString('N') + '.ini')
        $original = "[General]${eol}Enabled=0${eol}[Bindings]${eol}Consumable3=81${eol}"
        [IO.File]::WriteAllText($path, $original, $utf8)
        & $migration -ConfigPath $path -CheckOnly
        Assert-Equal ([IO.File]::ReadAllText($path)) $original 'CheckOnly changed config'
        & $migration -ConfigPath $path
        $expected = $original.Replace("[General]$eol", "[General]${eol}ShowBothWheels=1${eol}")
        Assert-Equal ([IO.File]::ReadAllText($path)) $expected 'Migration changed unrelated content'
        $backups = @(Get-ChildItem -Path "$path.before-*.bak")
        Assert-Equal $backups.Count 1 'Missing or duplicate backup'
        Assert-Equal ([IO.File]::ReadAllText($backups[0].FullName)) $original 'Backup differs'
        & $migration -ConfigPath $path
        Assert-Equal ([IO.File]::ReadAllText($path)) $expected 'Migration is not idempotent'
        Assert-Equal (@(Get-ChildItem -Path "$path.before-*.bak").Count) 1 'Repeated migration added backup'
    }
    foreach ($choice in @('0', '1')) {
        $path = Join-Path $fixtureRoot "choice-$choice.ini"
        $original = "[General]`nShowBothWheels=$choice`nEnabled=0`n"
        [IO.File]::WriteAllText($path, $original, $utf8)
        & $migration -ConfigPath $path
        Assert-Equal ([IO.File]::ReadAllText($path)) $original 'Existing choice changed'
    }
    foreach ($invalid in @("[Other]`nX=1`n", "[General]`nShowBothWheels=2`n", "[General]`nShowBothWheels=0`nShowBothWheels=1`n", "[General]`n[General]`n")) {
        $path = Join-Path $fixtureRoot ([Guid]::NewGuid().ToString('N') + '.ini')
        [IO.File]::WriteAllText($path, $invalid, $utf8)
        $rejected = $false
        try { & $migration -ConfigPath $path } catch { $rejected = $true }
        if (-not $rejected) { throw 'Invalid configuration accepted' }
        Assert-Equal ([IO.File]::ReadAllText($path)) $invalid 'Invalid config was modified'
    }
    Write-Output 'PASS configuration migration preservation, backup, idempotence and rejection tests'
} finally {
    $resolved = [IO.Path]::GetFullPath($fixtureRoot)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if (-not $resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -notlike 'bdw-migration-*') { throw 'Unsafe cleanup target' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
