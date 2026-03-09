# ============================================================
#  locate.ps1  -  Fast recursive file/folder search
#  Version: 1.0
#
#  Usage:
#    locate <n>                  - search across C:\
#    locate <n> -Root D:\        - search from a different root
#    locate <n> -First           - stop at first match
#    locate <n> -CaseSensitive   - exact case matching
#    locate <n> -FilesOnly       - only return files
#    locate <n> -FoldersOnly     - only return folders
#    locate -update              - check GitHub for latest version
#    locate -uninstall           - remove locate from this machine
#    locate -remove-installer    - delete the installer script
#
#  Examples:
#    locate file.txt
#    locate reports
#    locate *.log -Root C:\Users
#    locate config -CaseSensitive
#    locate report.pdf -Root D:\ -First
# ============================================================

param(
    [Parameter(Position = 0)]
    [string]$Name,

    [string]$Root = "C:\",
    [switch]$CaseSensitive,
    [switch]$FilesOnly,
    [switch]$FoldersOnly,
    [switch]$First,
    [switch]$Update,
    [switch]$Uninstall,
    [switch]$RemoveInstaller
)

# ── Constants ───────────────────────────────────────────────
$currentVersion = "1.0"
$installDir     = Join-Path $env:USERPROFILE "Tools"
$scriptPath     = Join-Path $installDir "locate.ps1"
$configPath     = Join-Path $installDir "locate.config"
$rawUrl         = "https://github.com/SETFOP/Scripts-make_life_easier/raw/refs/heads/main/PowerShell/locate.ps1"
$displayUrl     = "https://github.com/SETFOP/Scripts-make_life_easier/blob/main/PowerShell/locate.ps1"

# ============================================================
#  -update  :  Check GitHub for a newer version
# ============================================================
if ($Update) {
    Write-Host ""
    Write-Host "  🔄  Checking GitHub for latest version ..." -ForegroundColor Cyan
    try {
        $remoteContent = Invoke-WebRequest -Uri $rawUrl -UseBasicParsing | Select-Object -ExpandProperty Content
        if ($remoteContent -match '#\s*Version:\s*([0-9]+\.[0-9]+)') {
            $remoteVersion = $matches[1]
            Write-Host "  📦  Installed version : $currentVersion"
            Write-Host "  🌐  GitHub version    : $remoteVersion"
            Write-Host ""
            if ([version]$remoteVersion -gt [version]$currentVersion) {
                Write-Host "  ✨  A newer version is available!" -ForegroundColor Yellow
                Write-Host "      Review changes here: $displayUrl"
                Write-Host ""
                $answer = Read-Host "  ❓  Update to v$remoteVersion now? (yes/no)"
                if ($answer.Trim().ToLower() -in @("yes", "y")) {
                    $remoteContent | Set-Content -Path $scriptPath -Encoding UTF8
                    Write-Host ""
                    Write-Host "  ✅  Updated to v$remoteVersion successfully!" -ForegroundColor Green
                    Write-Host "      Restart PowerShell for changes to take effect."
                } else {
                    Write-Host "  ⏭️   Update skipped." -ForegroundColor DarkGray
                }
            } else {
                Write-Host "  ✅  You are already on the latest version (v$currentVersion)." -ForegroundColor Green
            }
        } else {
            Write-Host "  ⚠️  Could not read version from GitHub script." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ❌  Failed to reach GitHub: $_" -ForegroundColor Red
    }
    Write-Host ""
    exit 0
}

# ============================================================
#  -uninstall  :  Remove locate from this machine
# ============================================================
if ($Uninstall) {
    Write-Host ""
    Write-Host "  🗑️   locate uninstaller" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  This will:"
    Write-Host "   • Remove the 'locate' function from your PowerShell profile"
    Write-Host "   • Remove '$installDir' from your PATH"
    Write-Host "   • Delete locate.ps1 and locate.config from '$installDir'"
    Write-Host ""
    Write-Host "  ℹ️   Note: install.ps1 will NOT be touched here." -ForegroundColor DarkGray
    Write-Host "       Use 'locate -remove-installer' for that separately." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  ℹ️   If you keep a copy of locate.ps1 elsewhere," -ForegroundColor DarkGray
    Write-Host "       you can still run it directly with .\locate.ps1 <n>" -ForegroundColor DarkGray
    Write-Host "       and re-install anytime." -ForegroundColor DarkGray
    Write-Host ""
    $answer = Read-Host "  ❓  Proceed with uninstall? (yes/no)"
    if ($answer.Trim().ToLower() -notin @("yes", "y")) {
        Write-Host ""
        Write-Host "  ⏭️   Uninstall cancelled." -ForegroundColor DarkGray
        Write-Host ""
        exit 0
    }

    # Remove function block from PowerShell profile
    $profilePath = $PROFILE.CurrentUserAllHosts
    if (Test-Path $profilePath) {
        $profileContent = Get-Content $profilePath -Raw
        $cleaned = $profileContent -replace "(?s)\r?\n# ── locate - added by locate installer ──.*?# ────────────────────────────────────────────────────────────\r?\n", ""
        Set-Content -Path $profilePath -Value $cleaned.TrimEnd() -Encoding UTF8
        Write-Host "  ✅  Removed 'locate' function from PowerShell profile." -ForegroundColor Green
    }

    # Remove Tools folder from user PATH
    $currentPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    $newPath = ($currentPath -split ";" | Where-Object { $_.TrimEnd("\") -ne $installDir.TrimEnd("\") }) -join ";"
    [System.Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
    Write-Host "  ✅  Removed '$installDir' from PATH." -ForegroundColor Green

    # Delete locate.ps1 and locate.config
    @($scriptPath, $configPath) | ForEach-Object {
        if (Test-Path $_) {
            Remove-Item $_ -Force
            Write-Host "  ✅  Deleted: $_" -ForegroundColor Green
        }
    }

    # Clean up Tools folder if now empty
    if ((Test-Path $installDir) -and (-not (Get-ChildItem $installDir))) {
        Remove-Item $installDir -Force
        Write-Host "  ✅  Removed empty Tools folder." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "  👋  locate has been uninstalled. Restart PowerShell to apply changes." -ForegroundColor Cyan
    Write-Host ""
    exit 0
}

# ============================================================
#  -remove-installer  :  Delete install.ps1
# ============================================================
if ($RemoveInstaller) {
    Write-Host ""

    $installerPath = $null
    if (Test-Path $configPath) {
        $configLines = Get-Content $configPath | Where-Object { $_ -notmatch "^\s*#" -and $_ -match "InstallerPath=" }
        if ($configLines) {
            $installerPath = ($configLines[0] -split "=", 2)[1].Trim()
        }
    }

    if (-not $installerPath -or -not (Test-Path $installerPath)) {
        Write-Host "  ⚠️  Could not locate install.ps1 — it may have already been deleted." -ForegroundColor Yellow
        Write-Host ""
        exit 0
    }

    Write-Host "  🗑️   Found installer at:" -ForegroundColor Cyan
    Write-Host "       $installerPath"
    Write-Host ""
    $answer = Read-Host "  ❓  Delete install.ps1? (yes/no)"
    if ($answer.Trim().ToLower() -in @("yes", "y")) {
        Remove-Item $installerPath -Force
        Write-Host ""
        Write-Host "  ✅  install.ps1 deleted successfully." -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "  ⏭️   Skipped. install.ps1 was not deleted." -ForegroundColor DarkGray
    }
    Write-Host ""
    exit 0
}

# ============================================================
#  Main search
# ============================================================
if (-not $Name) {
    Write-Host ""
    Write-Host "  Usage: locate <n> [options]" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Options:"
    Write-Host "    -Root <path>       Search from a specific folder or drive"
    Write-Host "    -First             Stop at first match"
    Write-Host "    -CaseSensitive     Match exact case"
    Write-Host "    -FilesOnly         Return files only"
    Write-Host "    -FoldersOnly       Return folders only"
    Write-Host "    -update            Check GitHub for a newer version"
    Write-Host "    -uninstall         Remove locate from this machine"
    Write-Host "    -remove-installer  Delete the install.ps1 script"
    Write-Host ""
    exit 0
}

if (-not (Test-Path $Root)) {
    Write-Error "Root path '$Root' does not exist."
    exit 1
}

$sw = [System.Diagnostics.Stopwatch]::StartNew()

Write-Host ""
Write-Host "  🔍  Searching for: " -NoNewline
Write-Host "$Name" -ForegroundColor Cyan
Write-Host ""

# ── Collect top-level directories ──────────────────────────
$topDirs = @()
try {
    $topDirs = [System.IO.Directory]::GetDirectories($Root)
} catch {
    Write-Warning "Could not enumerate '$Root': $_"
}

$totalDirs  = $topDirs.Count
$scannedDir = [System.Collections.Concurrent.ConcurrentDictionary[string,byte]]::new()
$resultBag  = [System.Collections.Concurrent.ConcurrentBag[string]]::new()
$stopFlag   = [System.Collections.Concurrent.ConcurrentDictionary[string,byte]]::new()

# ── Runspace pool ───────────────────────────────────────────
$MaxThreads = 8
$pool = [RunspaceFactory]::CreateRunspacePool(1, $MaxThreads)
$pool.Open()

# ── Worker script block ─────────────────────────────────────
$workerScript = {
    param(
        [string]$SearchRoot,
        [string]$Pattern,
        [bool]$CaseSensitive,
        [bool]$FilesOnly,
        [bool]$FoldersOnly,
        [bool]$First,
        [System.Collections.Concurrent.ConcurrentBag[string]]$Bag,
        [System.Collections.Concurrent.ConcurrentDictionary[string,byte]]$StopFlag,
        [System.Collections.Concurrent.ConcurrentDictionary[string,byte]]$ScannedDir
    )

    function Matches-Pattern {
        param([string]$input, [string]$pattern, [bool]$cs)
        if ($cs) { return $input -clike $pattern }
        else      { return $input -like  $pattern }
    }

    $stack = [System.Collections.Generic.Stack[string]]::new()
    $stack.Push($SearchRoot)

    while ($stack.Count -gt 0) {
        if ($First -and $StopFlag.Count -gt 0) { break }

        $current = $stack.Pop()
        [void]$ScannedDir.TryAdd($current, 0)

        if (-not $FoldersOnly) {
            try {
                foreach ($f in [System.IO.Directory]::EnumerateFiles($current)) {
                    if ($First -and $StopFlag.Count -gt 0) { break }
                    $leaf = [System.IO.Path]::GetFileName($f)
                    if (Matches-Pattern $leaf $Pattern $CaseSensitive) {
                        $Bag.Add($f)
                        if ($First) { [void]$StopFlag.TryAdd("stop", 0); break }
                    }
                }
            } catch {}
        }

        try {
            foreach ($d in [System.IO.Directory]::EnumerateDirectories($current)) {
                if ($First -and $StopFlag.Count -gt 0) { break }
                if (-not $FilesOnly) {
                    $leaf = [System.IO.Path]::GetFileName($d)
                    if (Matches-Pattern $leaf $Pattern $CaseSensitive) {
                        $Bag.Add($d)
                        if ($First) { [void]$StopFlag.TryAdd("stop", 0); break }
                    }
                }
                $stack.Push($d)
            }
        } catch {}
    }
}

# ── Wildcard wrap ───────────────────────────────────────────
$searchPattern = $Name
if ($Name -notmatch '\*|\?|\[') { $searchPattern = "*$Name*" }

# ── Dispatch jobs ───────────────────────────────────────────
$jobs = [System.Collections.Generic.List[hashtable]]::new()

foreach ($dir in $topDirs) {
    $ps = [PowerShell]::Create()
    $ps.RunspacePool = $pool
    [void]$ps.AddScript($workerScript)
    [void]$ps.AddParameter("SearchRoot",    $dir)
    [void]$ps.AddParameter("Pattern",       $searchPattern)
    [void]$ps.AddParameter("CaseSensitive", $CaseSensitive.IsPresent)
    [void]$ps.AddParameter("FilesOnly",     $FilesOnly.IsPresent)
    [void]$ps.AddParameter("FoldersOnly",   $FoldersOnly.IsPresent)
    [void]$ps.AddParameter("First",         $First.IsPresent)
    [void]$ps.AddParameter("Bag",           $resultBag)
    [void]$ps.AddParameter("StopFlag",      $stopFlag)
    [void]$ps.AddParameter("ScannedDir",    $scannedDir)
    $jobs.Add(@{ PS = $ps; Handle = $ps.BeginInvoke() })
}

# ── Live progress display ───────────────────────────────────
$spinner = '⠋','⠙','⠹','⠸','⠼','⠴','⠦','⠧','⠇','⠏'
$i = 0
while ($jobs | Where-Object { -not $_.Handle.IsCompleted }) {
    $scanned  = $scannedDir.Count
    $pct      = if ($totalDirs -gt 0) { [math]::Min(99, [int](($scanned / $totalDirs) * 100)) } else { 0 }
    $lastDir  = if ($scanned -gt 0) { ($scannedDir.Keys | Select-Object -Last 1) } else { $Root }
    $shortDir = if ($lastDir.Length -gt 52) { "..." + $lastDir.Substring($lastDir.Length - 49) } else { $lastDir }
    $found    = $resultBag.Count

    Write-Host "`r  $($spinner[$i % $spinner.Count])  [$("{0,3}" -f $pct)%]  Scanning: $shortDir   ($found found)     " -NoNewline
    Start-Sleep -Milliseconds 100
    $i++
}

Write-Host "`r  ✅  Scan complete.                                                              "

# ── Cleanup runspaces ───────────────────────────────────────
foreach ($job in $jobs) {
    try { $job.PS.EndInvoke($job.Handle) } catch {}
    $job.PS.Dispose()
}
$pool.Close()
$pool.Dispose()
$sw.Stop()

# ── Output results ──────────────────────────────────────────
$results = $resultBag.ToArray() | Sort-Object

Write-Host ""

if ($results.Count -eq 0) {
    Write-Host "  ⚠️  No matches found for '$Name' under $Root" -ForegroundColor Yellow
} else {
    $label = if ($First -and $results.Count -eq 1) { "first match" } else { "match$(if($results.Count -ne 1){'es'})" }
    Write-Host "  📋  Results  ($($results.Count) $label):" -ForegroundColor Green
    Write-Host "  $('─' * 65)"

    $counter = 1
    foreach ($r in $results) {
        $isDir = [System.IO.Directory]::Exists($r)
        $icon  = if ($isDir) { "📁" } else { "📄" }
        $leaf  = [System.IO.Path]::GetFileName($r)
        $dir   = [System.IO.Path]::GetDirectoryName($r)
        Write-Host "  $icon  $counter`: " -NoNewline
        Write-Host "$leaf" -ForegroundColor Cyan -NoNewline
        Write-Host "   path: $dir"
        $counter++
    }
}

Write-Host ""
Write-Host "  ⏱️  Elapsed: $($sw.Elapsed.TotalSeconds.ToString('F2'))s" -ForegroundColor DarkGray
Write-Host ""
