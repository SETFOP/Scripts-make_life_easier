# ============================================================
#  locate.ps1  -  Fast parallel file/folder search
#  Version: 1.1
#
#  Usage:
#    locate <name>               - search across ALL drives
#    locate <name> -Root D:\     - search from a specific root
#    locate <name> -First        - stop at first match
#    locate <name> -CaseSensitive
#    locate <name> -FilesOnly
#    locate <name> -FoldersOnly
#    locate -update              - check GitHub for latest version
#    locate -uninstall           - remove locate from this machine
#    locate -remove-installer    - delete the installer script
#
#  Examples:
#    locate file.txt
#    locate reports
#    locate *.log
#    locate config -CaseSensitive
#    locate report.pdf -Root D:\ -First
# ============================================================

param(
    [Parameter(Position = 0)]
    [string]$Name,

    [string]$Root = "",              # Empty = search ALL drives
    [switch]$CaseSensitive,
    [switch]$FilesOnly,
    [switch]$FoldersOnly,
    [switch]$First,
    [switch]$Update,
    [switch]$Uninstall,
    [switch]$RemoveInstaller
)

# ── Constants ───────────────────────────────────────────────
$currentVersion = "1.1"
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
    Write-Host "       you can still run it directly with .\locate.ps1 <name>" -ForegroundColor DarkGray
    Write-Host "       and re-install anytime." -ForegroundColor DarkGray
    Write-Host ""
    $answer = Read-Host "  ❓  Proceed with uninstall? (yes/no)"
    if ($answer.Trim().ToLower() -notin @("yes", "y")) {
        Write-Host ""
        Write-Host "  ⏭️   Uninstall cancelled." -ForegroundColor DarkGray
        Write-Host ""
        exit 0
    }

    $profilePath = $PROFILE.CurrentUserAllHosts
    if (Test-Path $profilePath) {
        $profileContent = Get-Content $profilePath -Raw
        $cleaned = $profileContent -replace "(?s)\r?\n# ── locate - added by locate installer ──.*?# ────────────────────────────────────────────────────────────\r?\n", ""
        Set-Content -Path $profilePath -Value $cleaned.TrimEnd() -Encoding UTF8
        Write-Host "  ✅  Removed 'locate' function from PowerShell profile." -ForegroundColor Green
    }

    $currentPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    $newPath = ($currentPath -split ";" | Where-Object { $_.TrimEnd("\") -ne $installDir.TrimEnd("\") }) -join ";"
    [System.Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
    Write-Host "  ✅  Removed '$installDir' from PATH." -ForegroundColor Green

    @($scriptPath, $configPath) | ForEach-Object {
        if (Test-Path $_) {
            Remove-Item $_ -Force
            Write-Host "  ✅  Deleted: $_" -ForegroundColor Green
        }
    }

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
#  Help / no args
# ============================================================
if (-not $Name) {
    Write-Host ""
    Write-Host "  Usage: locate <name> [options]" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Options:"
    Write-Host "    -Root <path>       Search a specific folder or drive (default: all drives)"
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

# ============================================================
#  Resolve search roots
#  - If -Root was given, use that single path
#  - Otherwise, detect all mounted filesystem drives
# ============================================================
$searchRoots = @()

if ($Root -ne "") {
    # User specified a specific root
    if (-not (Test-Path $Root)) {
        Write-Error "Root path '$Root' does not exist."
        exit 1
    }
    $searchRoots = @($Root)
} else {
    # Auto-detect all mounted filesystem drives
    $searchRoots = Get-PSDrive -PSProvider FileSystem |
        Where-Object { $_.Root -ne "" -and (Test-Path $_.Root) } |
        Select-Object -ExpandProperty Root
}

if ($searchRoots.Count -eq 0) {
    Write-Error "No valid drives or paths found to search."
    exit 1
}

# ── Normalize search pattern ────────────────────────────────
# If no wildcard characters are present, wrap in *…* for substring search
$searchPattern = $Name
if ($Name -notmatch '\*|\?|\[') { $searchPattern = "*$Name*" }

# ── Shared state ────────────────────────────────────────────
$resultBag   = [System.Collections.Concurrent.ConcurrentBag[string]]::new()
$stopFlag    = [System.Collections.Concurrent.ConcurrentDictionary[string,byte]]::new()
$progressBag = [System.Collections.Concurrent.ConcurrentDictionary[string,string]]::new()

# ── Runspace pool — one worker per drive ────────────────────
$MaxThreads = [math]::Max($searchRoots.Count, 4)
$pool = [RunspaceFactory]::CreateRunspacePool(1, $MaxThreads)
$pool.Open()

# ── Worker: scans one entire drive/root recursively ─────────
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
        [System.Collections.Concurrent.ConcurrentDictionary[string,string]]$ProgressBag
    )

    function Test-Match {
        param([string]$input, [string]$pattern, [bool]$cs)
        if ($cs) { return $input -clike $pattern }
        else      { return $input -like  $pattern }
    }

    # Iterative DFS — avoids stack overflow on deep trees
    $stack = [System.Collections.Generic.Stack[string]]::new()
    $stack.Push($SearchRoot)

    while ($stack.Count -gt 0) {
        # Honour -First stop signal from any thread
        if ($First -and $StopFlag.Count -gt 0) { break }

        $current = $stack.Pop()

        # Update live progress for this drive
        [void]$ProgressBag.AddOrUpdate($SearchRoot, $current, { $current })

        # ── Check files in current directory ───────────────
        if (-not $FoldersOnly) {
            try {
                # EnumerateFiles streams lazily — no full directory load into memory
                foreach ($f in [System.IO.Directory]::EnumerateFiles($current)) {
                    if ($First -and $StopFlag.Count -gt 0) { break }
                    $leaf = [System.IO.Path]::GetFileName($f)
                    if (Test-Match $leaf $Pattern $CaseSensitive) {
                        $Bag.Add($f)
                        if ($First) { [void]$StopFlag.TryAdd("stop", 0); break }
                    }
                }
            } catch {
                # Access denied or protected folder — skip silently
            }
        }

        # ── Recurse into subdirectories ─────────────────────
        try {
            foreach ($d in [System.IO.Directory]::EnumerateDirectories($current)) {
                if ($First -and $StopFlag.Count -gt 0) { break }

                # Check if the folder name itself is a match
                if (-not $FilesOnly) {
                    $leaf = [System.IO.Path]::GetFileName($d)
                    if (Test-Match $leaf $Pattern $CaseSensitive) {
                        $Bag.Add($d)
                        if ($First) { [void]$StopFlag.TryAdd("stop", 0); break }
                    }
                }

                $stack.Push($d)
            }
        } catch {
            # Access denied — skip silently and continue
        }
    }
}

# ── Dispatch one job per drive ──────────────────────────────
$jobs = [System.Collections.Generic.List[hashtable]]::new()

foreach ($root in $searchRoots) {
    $ps = [PowerShell]::Create()
    $ps.RunspacePool = $pool
    [void]$ps.AddScript($workerScript)
    [void]$ps.AddParameter("SearchRoot",    $root)
    [void]$ps.AddParameter("Pattern",       $searchPattern)
    [void]$ps.AddParameter("CaseSensitive", $CaseSensitive.IsPresent)
    [void]$ps.AddParameter("FilesOnly",     $FilesOnly.IsPresent)
    [void]$ps.AddParameter("FoldersOnly",   $FoldersOnly.IsPresent)
    [void]$ps.AddParameter("First",         $First.IsPresent)
    [void]$ps.AddParameter("Bag",           $resultBag)
    [void]$ps.AddParameter("StopFlag",      $stopFlag)
    [void]$ps.AddParameter("ProgressBag",   $progressBag)
    $jobs.Add(@{ PS = $ps; Handle = $ps.BeginInvoke(); Drive = $root })
}

# ── Start timer and display ─────────────────────────────────
$sw = [System.Diagnostics.Stopwatch]::StartNew()

Write-Host ""
Write-Host "  🔍  Searching for: " -NoNewline
Write-Host $Name -ForegroundColor Cyan

$driveList = $searchRoots -join "  "
Write-Host "  💾  Drives      : $driveList"
Write-Host ""

# ── Live progress loop ──────────────────────────────────────
$spinner   = '⠋','⠙','⠹','⠸','⠼','⠴','⠦','⠧','⠇','⠏'
$tick      = 0
$doneCount = 0
$total     = $jobs.Count

while ($jobs | Where-Object { -not $_.Handle.IsCompleted }) {
    $doneCount = ($jobs | Where-Object { $_.Handle.IsCompleted }).Count
    $pct       = if ($total -gt 0) { [math]::Min(99, [int](($doneCount / $total) * 100)) } else { 0 }
    $found     = $resultBag.Count

    # Show the most recently scanned path across all active workers
    $activePath = ""
    foreach ($kv in $progressBag.GetEnumerator()) {
        if ($kv.Value -ne "") { $activePath = $kv.Value; break }
    }
    $short = if ($activePath.Length -gt 55) { "..." + $activePath.Substring($activePath.Length - 52) } else { $activePath }

    Write-Host "`r  $($spinner[$tick % $spinner.Count])  [$("{0,3}" -f $pct)%]  $short   ($found found)     " -NoNewline
    Start-Sleep -Milliseconds 100
    $tick++
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
    $scope = if ($Root -ne "") { "under $Root" } else { "across all drives" }
    Write-Host "  ⚠️  No matches found for '$Name' $scope" -ForegroundColor Yellow
} else {
    $label = if ($First -and $results.Count -eq 1) { "first match" } else { "match$(if($results.Count -ne 1){'es'})" }
    Write-Host "  📋  Found ($($results.Count) $label):" -ForegroundColor Green
    Write-Host "  $('─' * 65)"

    $counter = 1
    foreach ($r in $results) {
        $isDir = [System.IO.Directory]::Exists($r)
        $icon  = if ($isDir) { "📁" } else { "📄" }
        $leaf  = [System.IO.Path]::GetFileName($r)
        $dir   = [System.IO.Path]::GetDirectoryName($r)
        Write-Host "  $icon  $counter`: " -NoNewline
        Write-Host $leaf -ForegroundColor Cyan -NoNewline
        Write-Host "   path: $dir"
        $counter++
    }
}

Write-Host ""
Write-Host "  ⏱️  Elapsed: $($sw.Elapsed.TotalSeconds.ToString('F2'))s" -ForegroundColor DarkGray
Write-Host ""
