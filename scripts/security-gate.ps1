<#
.SYNOPSIS
    Executable security & reliability gate for any project.
.DESCRIPTION
    Scans tracked (and new untracked) files for leaked secrets, disabled security
    controls, dangerous installer patterns and syntax errors. Returns exit code 1
    if anything unexcused is found, so it can gate a commit or CI step.

    Deliberate exceptions go into "<repo>/.security-gate-allow", one rule-id or
    literal substring per line, with a reason after '#'. Excused findings are
    still printed, never silently dropped.
.PARAMETER ProjectPath
    Project (or repository) directory. Defaults to the current location.
.PARAMETER SkipSyntax
    Skip py_compile / node --check / sh -n.
.PARAMETER CheckLinks
    Additionally verify that URLs referenced in README/docs answer HTTP 200.
    Off by default: it needs network access.
.EXAMPLE
    & "C:\Users\Salomanov\.gemini\config\skills\project-guardian\scripts\security-gate.ps1" -ProjectPath "E:\Projects\Router_api"
#>

param(
    [string]$ProjectPath = (Get-Location).Path,
    [switch]$SkipSyntax,
    [switch]$CheckLinks
)

$ErrorActionPreference = "Continue"

# --- Locate repository root and file list -------------------------------

$root = $ProjectPath
$isGit = $false
try {
    $top = (& git -C $ProjectPath rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -eq 0 -and $top) {
        $root = $top.Trim()
        $isGit = $true
    }
} catch { }

$skipDir = '[\\/](\.git|\.backups|node_modules|graphify-out|__pycache__|dist|build|venv|\.venv)[\\/]'

$binaryExt = @('.png', '.jpg', '.jpeg', '.gif', '.ico', '.zip', '.gz', '.ipk', '.bin', '.hex',
               '.elf', '.pyc', '.pdf', '.woff', '.woff2', '.ttf', '.so', '.dll', '.exe')

function Get-ProjectFiles {
    if ($isGit) {
        $files = & git -C $root ls-files --cached --others --exclude-standard 2>$null
        return @($files | Where-Object { $_ -and $_ -notmatch $skipDir })
    }
    return @(Get-ChildItem -Path $root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch $skipDir } |
        ForEach-Object { $_.FullName.Substring($root.Length).TrimStart('\', '/') })
}

$files = Get-ProjectFiles
Write-Host "[gate] project: $root ($($files.Count) files)" -ForegroundColor Cyan

# --- Rule definitions ---------------------------------------------------

# type: secret | anti | syntax
$rules = @(
    @{ Id = 'SEC-001'; Type = 'secret'; Glob = '*'; Pattern = '(?i)(?<![/\\.\w-])Salomanov(?![/\\.\w-])'
       Message = 'known leaked credential literal (not part of a URL/domain/path)' },
    @{ Id = 'SEC-002'; Type = 'secret'; Glob = '*.py'
       Pattern = '(?i)(password|passwd|secret|api_key|apikey|token)\s*=\s*["''][^"''\s]{3,}["'']'
       Message = 'hardcoded credential literal' },
    @{ Id = 'SEC-003'; Type = 'secret'; Glob = '*'
       Pattern = 'BEGIN (RSA|OPENSSH|EC|DSA|PGP) PRIVATE KEY'
       Message = 'private key in repository' },
    @{ Id = 'SEC-004'; Type = 'secret'; Glob = '*'
       Pattern = 'AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{20,}|[0-9]{9,10}:[A-Za-z0-9_-]{35}'
       Message = 'cloud/bot token in repository' },

    @{ Id = 'SEC-010'; Type = 'anti'; Glob = '*.sh'
       Pattern = '\|\s*(sh|bash)\b'
       Message = 'curl/wget piped into a shell hides download failures' },
    @{ Id = 'SEC-011'; Type = 'anti'; Glob = '*.sh'
       Pattern = '\bpython3?\s+-c\s'
       Message = 'inline python -c in shell scripts' },
    @{ Id = 'SEC-012'; Type = 'anti'; Glob = '*.sh'
       Pattern = '\bchmod\s+(-R\s+)?777\b'
       Message = 'world-writable permissions' },
    @{ Id = 'SEC-013'; Type = 'anti'; Glob = '*.py'
       Pattern = 'verify\s*=\s*False'
       Message = 'TLS verification disabled' },
    @{ Id = 'SEC-014'; Type = 'anti'; Glob = '*.py'
       Pattern = 'shell\s*=\s*True'
       Message = 'shell=True executes client-controlled strings (justify in .security-gate-allow)' },
    @{ Id = 'SEC-015'; Type = 'anti'
       Glob = @('*.py', '*.js', '*.php', '*.conf', '*.ini', '*.yml', '*.yaml', '*.json', '*.sh')
       Pattern = 'auth[._]enabled\s*[:=]\s*(false|False|0)'
       Message = 'authentication disabled' },
    @{ Id = 'SEC-016'; Type = 'anti'; Glob = '*'
       Pattern = 'Access-Control-Allow-Origin[''"]?\s*[,:]\s*[''"]\*'
       Message = 'wildcard CORS on an API' },
    @{ Id = 'SEC-017'; Type = 'anti'; Glob = '*'
       Pattern = 'rejectUnauthorized\s*:\s*false|InsecureSkipVerify\s*:\s*true'
       Message = 'TLS verification disabled' }
)

$secretFileNames = @('\.env$', '\.env\.[a-z]+$', '\.pem$', '\.pfx$', '\.p12$',
                     'id_rsa$', 'id_ed25519$', 'credentials\.json$')

# --- Allowlist ----------------------------------------------------------

$allowFile = Join-Path $root '.security-gate-allow'
$allow = @()
if (Test-Path $allowFile) {
    foreach ($line in Get-Content $allowFile -Encoding UTF8) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
        $reason = ''
        $pattern = $trimmed
        if ($trimmed.Contains('#')) {
            $pattern = $trimmed.Substring(0, $trimmed.IndexOf('#')).Trim()
            $reason = $trimmed.Substring($trimmed.IndexOf('#') + 1).Trim()
        }
        if ($pattern) { $allow += [pscustomobject]@{ Pattern = $pattern; Reason = $reason } }
    }
}

function Test-Excused([string]$ruleId, [string]$text) {
    foreach ($entry in $allow) {
        if ($text -like "*$($entry.Pattern)*" -or $ruleId -eq $entry.Pattern) {
            return $entry
        }
    }
    return $null
}

# --- Scan ---------------------------------------------------------------

$findings = @()
$excused = @()

foreach ($name in $files) {
    $ext = [System.IO.Path]::GetExtension($name).ToLowerInvariant()
    if ($binaryExt -contains $ext) { continue }
    # The scanner itself contains the patterns it looks for
    if ($name -like '*security-gate.ps1') { continue }

    foreach ($namePattern in $secretFileNames) {
        if ($name -match $namePattern) {
            $findings += [pscustomobject]@{ Id = 'SEC-005'; File = $name; Line = 0
                Text = "sensitive file tracked by git: $name" }
        }
    }

    $full = Join-Path $root $name
    if (-not (Test-Path $full -PathType Leaf)) { continue }
    try {
        if ((Get-Item $full).Length -gt 1MB) { continue }
        $content = [System.IO.File]::ReadAllText($full)
    } catch { continue }
    if (-not $content) { continue }
    if ($content.Contains([char]0)) { continue }

    $lines = $content -split "`r?`n"
    for ($i = 0; $i -lt $lines.Length; $i++) {
        $line = $lines[$i]
        if (-not $line) { continue }
        foreach ($rule in $rules) {
            $globs = @($rule.Glob)
            if ($globs -notcontains '*') {
                $globMatch = $false
                foreach ($g in $globs) {
                    if ($name -like $g) { $globMatch = $true; break }
                }
                if (-not $globMatch) { continue }
            }
            if ($line -notmatch $rule.Pattern) { continue }
            $entry = [pscustomobject]@{
                Id = $rule.Id; File = $name; Line = ($i + 1)
                Text = $line.Trim(); Message = $rule.Message
            }
            $why = Test-Excused $rule.Id $line
            if ($why) { $entry | Add-Member -NotePropertyName Reason -NotePropertyValue $why.Reason
                        $excused += $entry } else { $findings += $entry }
        }
    }
}

# --- Syntax checks ------------------------------------------------------

$syntaxFailures = @()

if (-not $SkipSyntax) {
    $python = Get-Command python -ErrorAction SilentlyContinue
    $node = Get-Command node -ErrorAction SilentlyContinue
    $bashSh = @("C:\Program Files\Git\bin\sh.exe", "C:\Program Files\Git\usr\bin\sh.exe") |
        Where-Object { Test-Path $_ } | Select-Object -First 1

    foreach ($name in $files) {
        $full = Join-Path $root $name
        if (-not (Test-Path $full -PathType Leaf)) { continue }
        $ext = [System.IO.Path]::GetExtension($name).ToLowerInvariant()

        if ($ext -eq '.py' -and $python) {
            & $python.Source -m py_compile $full 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { $syntaxFailures += "python: $name" }
        }
        elseif ($ext -eq '.js' -and $node) {
            $null = & $node.Source --check $full 2>&1
            if ($LASTEXITCODE -ne 0) { $syntaxFailures += "node: $name" }
        }
        elseif (($ext -eq '.sh' -or $name -match '(^|/)S\d{2}') -and $bashSh) {
            if ($name -match '(^|/)S\d{2}') {
                try {
                    $head = Get-Content $full -TotalCount 1 -Encoding UTF8
                    if ($head -notmatch 'sh') { continue }
                } catch { continue }
            }
            $null = & $bashSh -n $full 2>&1
            if ($LASTEXITCODE -ne 0) { $syntaxFailures += "sh: $name" }
        }
    }
}

# --- Optional link check ------------------------------------------------

$linkFailures = @()
if ($CheckLinks) {
    foreach ($name in $files) {
        if ($name -notmatch '\.(md|sh|py)$') { continue }
        $full = Join-Path $root $name
        if (-not (Test-Path $full)) { continue }
        $text = [System.IO.File]::ReadAllText($full)
        $urls = [regex]::Matches($text, 'https?://[^\s"''<>)]+') |
            ForEach-Object { $_.Value } | Sort-Object -Unique
        foreach ($url in $urls) {
            try {
                $resp = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 10 -UseBasicParsing
                if ($resp.StatusCode -ne 200) { $linkFailures += "$name -> $url ($($resp.StatusCode))" }
            } catch {
                $linkFailures += "$name -> $url (unreachable)"
            }
        }
    }
}

# --- Report -------------------------------------------------------------

Write-Host ""
if ($excused.Count -gt 0) {
    Write-Host "Excused (from .security-gate-allow):" -ForegroundColor DarkYellow
    foreach ($e in $excused) {
        $reason = ''
        if ($e.PSObject.Properties['Reason']) { $reason = $e.Reason }
        Write-Host ("  ~ {0} {1}:{2} -- {3} [{4}]" -f $e.Id, $e.File, $e.Line, $e.Text, $reason) -ForegroundColor DarkYellow
    }
    Write-Host ""
}

foreach ($f in $findings) {
    $msg = ''
    if ($f.PSObject.Properties['Message']) { $msg = " -- $($f.Message)" }
    Write-Host ("  [FAIL] {0} {1}:{2}: {3}{4}" -f $f.Id, $f.File, $f.Line, $f.Text, $msg) -ForegroundColor Red
}
foreach ($s in $syntaxFailures) { Write-Host "  [FAIL] SYNTAX $s" -ForegroundColor Red }
foreach ($l in $linkFailures)   { Write-Host "  [FAIL] LINK   $l" -ForegroundColor Red }

$total = $findings.Count + $syntaxFailures.Count + $linkFailures.Count
if ($total -gt 0) {
    Write-Host ""
    Write-Host "SECURITY GATE FAILED: $total problem(s)." -ForegroundColor Red
    exit 1
}

Write-Host "SECURITY GATE PASSED ($($files.Count) files, $($excused.Count) excused)." -ForegroundColor Green
exit 0
