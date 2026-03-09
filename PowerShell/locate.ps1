# ============================================================
#  locate.ps1  -  Fast recursive file/folder search
#  Usage:  .\locate.ps1 <name>  [options]
#
#  Examples:
#    .\locate.ps1 file.txt
#    .\locate.ps1 folder
#    .\locate.ps1 file
#    .\locate.ps1 *.log -Root C:\Users
#    .\locate.ps1 config -CaseSensitive
#    .\locate.ps1 report.pdf -Root D:\ -MaxThreads 16
# ============================================================

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Name,

    [string]$Root = "C:\",                  # Starting drive/folder
    [int]$MaxThreads = 8,                   # Runspace pool size
    [switch]$CaseSensitive,                 # Exact-case matching
    [switch]$FilesOnly,                     # Suppress folder matches
    [switch]$FoldersOnly                    # Suppress file matches
)

# ── Validate ───────────────────────────────────────────────
if (-not (Test-Path $Root)) {
    Write-Error "Root path '$Root' does not exist."
    exit 1
}

$sw = [System.Diagnostics.Stopwatch]::StartNew()

Write-Host ""
Write-Host "  🔍  locate  →  searching for: " -NoNewline
Write-Host "$Name" -ForegroundColor Cyan
Write-Host "  📂  Root    : $Root"
Write-Host "  🧵  Threads : $MaxThreads"
Write-Host ""

# ── Collect top-level directories to fan out across threads ─
$topDirs = @()
try {
    $topDirs = [System.IO.Directory]::GetDirectories($Root)
} catch {
    Write-Warning "Could not enumerate '$Root': $_"
}

# Also search the root itself for direct children
$rootPath = $Root

# ── Thread-safe result bag ──────────────────────────────────
$resultBag = [System.Collections.Concurrent.ConcurrentBag[string]]::new()

# ── Build the runspace pool ─────────────────────────────────
$pool = [RunspaceFactory]::CreateRunspacePool(1, $MaxThreads)
$pool.Open()

# ── Script block executed in each thread ───────────────────
$workerScript = {
    param(
        [string]$SearchRoot,
        [string]$Pattern,
        [bool]$CaseSensitive,
        [bool]$FilesOnly,
        [bool]$FoldersOnly,
        [System.Collections.Concurrent.ConcurrentBag[string]]$Bag
    )

    $comparison = if ($CaseSensitive) {
        [System.StringComparison]::Ordinal
    } else {
        [System.StringComparison]::OrdinalIgnoreCase
    }

    # Convert glob pattern to a usable wildcard check via -like operator
    function Matches-Pattern {
        param([string]$input, [string]$pattern, [bool]$cs)
        if ($cs) { return $input -clike $pattern }
        else      { return $input -like  $pattern }
    }

    # Iterative DFS using a stack (avoids deep recursion / stack overflows)
    $stack = [System.Collections.Generic.Stack[string]]::new()
    $stack.Push($SearchRoot)

    while ($stack.Count -gt 0) {
        $current = $stack.Pop()

        # --- Enumerate files ---
        if (-not $FoldersOnly) {
            try {
                $files = [System.IO.Directory]::EnumerateFiles($current)
                foreach ($f in $files) {
                    $leaf = [System.IO.Path]::GetFileName($f)
                    if (Matches-Pattern $leaf $Pattern $CaseSensitive) {
                        $Bag.Add($f)
                    }
                }
            } catch { <# access denied / skipped #> }
        }

        # --- Enumerate subdirectories ---
        try {
            $dirs = [System.IO.Directory]::EnumerateDirectories($current)
            foreach ($d in $dirs) {
                # Check if the folder name itself matches
                if (-not $FilesOnly) {
                    $leaf = [System.IO.Path]::GetFileName($d)
                    if (Matches-Pattern $leaf $Pattern $CaseSensitive) {
                        $Bag.Add($d)
                    }
                }
                $stack.Push($d)
            }
        } catch { <# access denied / skipped #> }
    }
}

# ── Dispatch one runspace per top-level directory ──────────
$jobs = [System.Collections.Generic.List[hashtable]]::new()

# Wildcard: if no wildcard chars present, wrap in *…* for substring search
$searchPattern = $Name
if ($Name -notmatch '\*|\?|\[') {
    $searchPattern = "*$Name*"
}

foreach ($dir in $topDirs) {
    $ps = [PowerShell]::Create()
    $ps.RunspacePool = $pool
    [void]$ps.AddScript($workerScript)
    [void]$ps.AddParameter("SearchRoot",   $dir)
    [void]$ps.AddParameter("Pattern",      $searchPattern)
    [void]$ps.AddParameter("CaseSensitive",$CaseSensitive.IsPresent)
    [void]$ps.AddParameter("FilesOnly",    $FilesOnly.IsPresent)
    [void]$ps.AddParameter("FoldersOnly",  $FoldersOnly.IsPresent)
    [void]$ps.AddParameter("Bag",          $resultBag)

    $jobs.Add(@{
        PS     = $ps
        Handle = $ps.BeginInvoke()
    })
}

# Also scan the root level itself (files/folders sitting directly in $Root)
$rootPs = [PowerShell]::Create()
$rootPs.RunspacePool = $pool
[void]$rootPs.AddScript({
    param($SearchRoot, $Pattern, $CaseSensitive, $FilesOnly, $FoldersOnly, $Bag)

    function Matches-Pattern {
        param([string]$i, [string]$p, [bool]$cs)
        if ($cs) { return $i -clike $p } else { return $i -like $p }
    }

    if (-not $FoldersOnly) {
        try {
            foreach ($f in [System.IO.Directory]::EnumerateFiles($SearchRoot)) {
                $leaf = [System.IO.Path]::GetFileName($f)
                if (Matches-Pattern $leaf $Pattern $CaseSensitive) { $Bag.Add($f) }
            }
        } catch {}
    }
    if (-not $FilesOnly) {
        try {
            foreach ($d in [System.IO.Directory]::EnumerateDirectories($SearchRoot)) {
                $leaf = [System.IO.Path]::GetFileName($d)
                if (Matches-Pattern $leaf $Pattern $CaseSensitive) { $Bag.Add($d) }
            }
        } catch {}
    }
})
[void]$rootPs.AddParameter("SearchRoot",   $rootPath)
[void]$rootPs.AddParameter("Pattern",      $searchPattern)
[void]$rootPs.AddParameter("CaseSensitive",$CaseSensitive.IsPresent)
[void]$rootPs.AddParameter("FilesOnly",    $FilesOnly.IsPresent)
[void]$rootPs.AddParameter("FoldersOnly",  $FoldersOnly.IsPresent)
[void]$rootPs.AddParameter("Bag",          $resultBag)
$jobs.Add(@{ PS = $rootPs; Handle = $rootPs.BeginInvoke() })

# ── Spinner while waiting ───────────────────────────────────
$spinner = '⠋','⠙','⠹','⠸','⠼','⠴','⠦','⠧','⠇','⠏'
$i = 0
while ($jobs | Where-Object { -not $_.Handle.IsCompleted }) {
    Write-Host "`r  $($spinner[$i % $spinner.Count])  Scanning …  ($($resultBag.Count) found so far)   " -NoNewline
    Start-Sleep -Milliseconds 80
    $i++
}
Write-Host "`r  ✅  Scan complete.                                    " 

# ── Clean up runspaces ──────────────────────────────────────
foreach ($job in $jobs) {
    try { $job.PS.EndInvoke($job.Handle) } catch {}
    $job.PS.Dispose()
}
$pool.Close()
$pool.Dispose()

$sw.Stop()

# ── Output results ──────────────────────────────────────────
$results = $resultBag.ToArray() | Sort-Object

if ($results.Count -eq 0) {
    Write-Host ""
    Write-Host "  ⚠️  No matches found for '$Name' under $Root" -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "  📋  Results  ($($results.Count) match$(if($results.Count -ne 1){'es'})):" -ForegroundColor Green
    Write-Host "  $('─' * 60)"

    foreach ($r in $results) {
        $isDir = [System.IO.Directory]::Exists($r)
        $icon  = if ($isDir) { "📁" } else { "📄" }
        Write-Host "  $icon  $r"
    }
}

Write-Host ""
Write-Host "  ⏱️  Elapsed: $($sw.Elapsed.TotalSeconds.ToString('F2'))s" -ForegroundColor DarkGray
Write-Host ""
