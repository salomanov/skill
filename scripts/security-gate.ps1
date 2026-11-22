<#
.SYNOPSIS
    Executable security & reliability gate for any project.
.DESCRIPTION
    Scans tracked (and new untracked) files for leaked secrets, disabled security
    controls, dangerous installer patterns, syntax errors, UTF-8 BOM violations
    in Linux/Android files (SYNTAX-BOM), and unarchived recommendations (REC-001).
    Returns exit code 1 if anything unexcused is found, so it can gate a commit or CI step.

    Deliberate exceptions go into "<repo>/.security-gate-allow", one rule-id or
    literal substring per line, with a reason after '#'. Excused findings are
    still printed, never silently dropped.
.PARAMETER ProjectPath
    Project (or repository) directory. Defaults to the current location.
.PARAMETER SkipSyntax
    Skip py_compile / node --check / sh -n / ps1 AST / BOM checks.
.PARAMETER CheckLinks
    Additionally verify that URLs referenced in README/docs answer HTTP 200.
    Off by default: it needs network access.
.EXAMPLE
    & "C:\Users\Salomanov\.gemini\config\skills\project-guardian\scripts\security-gate.ps1" -ProjectPath "E:\Projects\Router_Workspace\Opds"
#>

param(
    [string]$ProjectPath = (Get-Location).Path,
    [switch]$SkipSyntax,
    [switch]$CheckLinks,
    [string]$ConversationId = ""
)

$ErrorActionPreference = "Continue"
$env:PYTHONIOENCODING = "utf-8"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# --- Mechanical Step Counter & Context Hygiene Guard (v2.2: считаем ШАГИ, а не строки лога) ---
$sessionGuardLib = Join-Path $PSScriptRoot 'session-guard.ps1'
if (Test-Path -LiteralPath $sessionGuardLib -PathType Leaf) {
    . $sessionGuardLib
} else {
    # Библиотека недоступна: счетчик молчит, чтобы не выдавать ложных тревог
    function Get-ActiveSessionStepCount {
        param([string]$TargetConversationId = "", [int]$Threshold = 500, [string]$ProjectPath = "", [switch]$NoWarn)
        return 0
    }
}

$activeSteps = Get-ActiveSessionStepCount -TargetConversationId $ConversationId -ProjectPath $ProjectPath

# --- Locate project root and file list -----------------------------------

$scanDir = $ProjectPath
if ($ProjectPath -and (Test-Path -LiteralPath $ProjectPath)) {
    $scanDir = (Get-Item -LiteralPath $ProjectPath).FullName
}

$root = $scanDir
$gitRoot = $null
$isGit = $false
try {
    $top = (& git -C $scanDir rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -eq 0 -and $top) {
        $gitRoot = $top.Trim()
        $isGit = $true
    }
} catch { }

$skipDir = '(^|[\\/])(\.git|\.backups|node_modules|graphify-out|__pycache__|dist|build|venv|\.venv|scratch)[\\/]'

$binaryExt = @('.png', '.jpg', '.jpeg', '.gif', '.ico', '.zip', '.gz', '.ipk', '.bin', '.hex',
               '.elf', '.pyc', '.pdf', '.woff', '.woff2', '.ttf', '.so', '.dll', '.exe', '.apk')

function Get-ProjectFiles {
    if ($isGit) {
        $files = & git -C $scanDir ls-files --cached --others --exclude-standard . 2>$null
        return @($files | Where-Object { $_ -and $_ -notmatch $skipDir })
    }
    $baseDir = (Get-Item -LiteralPath $scanDir).FullName
    return @(Get-ChildItem -LiteralPath $baseDir -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch $skipDir } |
        ForEach-Object { $_.FullName.Substring($baseDir.Length).TrimStart('\', '/') })
}

$files = Get-ProjectFiles
Write-Host "[gate] project: $scanDir ($($files.Count) files)" -ForegroundColor Cyan

# --- Rule definitions ---------------------------------------------------

$rules = @(
    @{ Id = 'SEC-001'; Type = 'secret'; Glob = '*'; Pattern = '(?i)(?<![/\\.\w-])Salomanov(?![/\\.\w-])'
       Message = 'known leaked credential literal (not part of a URL/domain/path)' },
    @{ Id = 'SEC-002'; Type = 'secret'; Glob = @('*.py', '*.js', '*.ts', '*.json', '*.php', '*.cs')
       Pattern = '(?i)(password|passwd|secret|api_key|apikey|token)\s*[:=]\s*["''][^"''\s]{4,}["'']'
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
       Message = 'TLS verification disabled' },

    # PS-001 (регрессия #16): Test-Path без -LiteralPath падает WildcardPatternException на путях с [ ]
    @{ Id = 'PS-001'; Type = 'anti'; Glob = '*.ps1'
       Pattern = 'Test-Path\s+(?!-LiteralPath\b)'
       Message = 'Test-Path without -LiteralPath crashes on paths containing [ ] (WildcardPatternException)' }
)

$secretFileNames = @('\.env$', '\.env\.[a-z]+$', '\.pem$', '\.pfx$', '\.p12$',
                     'id_rsa$', 'id_ed25519$', 'credentials\.json$')

# --- Allowlist ----------------------------------------------------------

$allowFile = Join-Path $scanDir '.security-gate-allow'
if (-not (Test-Path -LiteralPath $allowFile) -and $gitRoot) {
    $allowFile = Join-Path $gitRoot '.security-gate-allow'
}

$allow = @()
$allowWarnings = @()
if (Test-Path -LiteralPath $allowFile) {
    $allowLineNo = 0
    foreach ($line in (Get-Content -LiteralPath $allowFile -Encoding UTF8)) {
        $allowLineNo++
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }

        $reason = ''
        $spec = $trimmed
        $hashPos = $spec.IndexOf('#')
        if ($hashPos -ge 0) {
            $reason = $spec.Substring($hashPos + 1).Trim()
            $spec = $spec.Substring(0, $hashPos).Trim()
        }
        if (-not $spec) { continue }

        # Строгий формат v2.2: "<RULE-ID> <путь[:строка]> # причина"
        $m = [regex]::Match($spec, '^(?<rule>[A-Z]{2,4}-\d{3})\s+(?<path>.+?)(?::(?<line>\d+))?$')
        if ($m.Success -and $reason) {
            $lineNum = 0
            if ($m.Groups['line'].Success) { $lineNum = [int]$m.Groups['line'].Value }
            $allow += [pscustomobject]@{
                Rule   = $m.Groups['rule'].Value
                Path   = $m.Groups['path'].Value.Trim()
                Line   = $lineNum
                Reason = $reason
                Strict = $true
                Source = "${allowFile}:$allowLineNo"
            }
        } else {
            # Устаревший формат (подстрока) — поддерживаем для чужих проектов, но предупреждаем
            $allow += [pscustomobject]@{
                Rule = ''; Path = $spec; Line = 0; Reason = $reason; Strict = $false
                Source = "${allowFile}:$allowLineNo"
            }
            $allowWarnings += "устаревшая запись без ID правила и причины (нужно '<RULE-ID> <путь[:строка]> # причина'): $spec"
        }
    }
}

function Test-Excused([string]$ruleId, [string]$fileName, [int]$lineNo, [string]$text) {    $normName = $fileName -replace '\\', '/'
    foreach ($entry in $allow) {
        if ($entry.Strict) {
            if ($entry.Rule -ne $ruleId) { continue }
            if ($entry.Line -gt 0 -and $entry.Line -ne $lineNo) { continue }
            $pattern = $entry.Path -replace '\\', '/'
            if ($pattern -match '[*?]') {
                if ($normName -like $pattern) { return $entry }
            } elseif ($normName -eq $pattern) {
                return $entry
            }
        } else {
            if ($text -like "*$($entry.Path)*" -or $ruleId -eq $entry.Path) { return $entry }
        }
    }
    return $null
}

foreach ($w in $allowWarnings) {
    Write-Host "[gate] ⚠️ $w" -ForegroundColor DarkYellow
}

# --- Scan ---------------------------------------------------------------

$findings = @()
$excused = @()

foreach ($name in $files) {
    $ext = [System.IO.Path]::GetExtension($name).ToLowerInvariant()
    if ($binaryExt -contains $ext) { continue }
    if ($name -like '*security-gate.ps1') { continue }

    if ($name -like '*.example' -or $name -like '*.sample' -or $name -like '*.template') {
        # skip filename secrets check for templates
    } else {
        foreach ($namePattern in $secretFileNames) {
            if ($name -match $namePattern) {
                $ex = Test-Excused 'SEC-005' $name 0 $name
                if ($ex) {
                    $excused += [pscustomobject]@{ Id = 'SEC-005'; File = $name; Line = 0
                        Text = "sensitive file tracked by git: $name"; Reason = $ex.Reason }
                } else {
                    $findings += [pscustomobject]@{ Id = 'SEC-005'; File = $name; Line = 0
                        Text = "sensitive file tracked by git: $name" }
                }
            }
        }
    }

    $full = Join-Path $scanDir $name
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { continue }
    try {
        if ((Get-Item -LiteralPath $full).Length -gt 1MB) { continue }
        $content = [System.IO.File]::ReadAllText($full, [System.Text.Encoding]::UTF8)
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
            $why = Test-Excused $rule.Id $name ($i + 1) $line
            if ($why) { $entry | Add-Member -NotePropertyName Reason -NotePropertyValue $why.Reason
                        $excused += $entry } else { $findings += $entry }
        }
    }
}

# --- REC-001: Recommendations Hygiene & Failure Log Status --------------
$recFile = Join-Path $scanDir 'AGENT_RECOMMENDATIONS.md'
$openRecCount = 0
if (Test-Path -LiteralPath $recFile -PathType Leaf) {
    try {
        $recLines = [System.IO.File]::ReadAllLines($recFile, [System.Text.Encoding]::UTF8)
        for ($i = 0; $i -lt $recLines.Length; $i++) {
            $rl = $recLines[$i]
            if ($rl -match '\[ \]\s*ТРЕБУЕТ ВНЕДРЕНИЯ') {
                $openRecCount++
            }
            if ($rl -match '\[x\]\s*ВЫПОЛНЕНО') {
                $entry = [pscustomobject]@{
                    Id = 'REC-001'; File = 'AGENT_RECOMMENDATIONS.md'; Line = ($i + 1)
                    Text = $rl.Trim(); Message = 'completed [x] items in AGENT_RECOMMENDATIONS.md must be archived to docs/APPLIED_RECOMMENDATIONS.md'
                }
                $why = Test-Excused 'REC-001' 'AGENT_RECOMMENDATIONS.md' ($i + 1) $rl
                if ($why) { $entry | Add-Member -NotePropertyName Reason -NotePropertyValue $why.Reason
                            $excused += $entry } else { $findings += $entry }
            }
        }
    } catch {}
}

if ($openRecCount -gt 0) {
    Write-Host "[gate] 📌 AGENT_RECOMMENDATIONS.md: $openRecCount открытых рекомендаций ([ ] ТРЕБУЕТ ВНЕДРЕНИЯ)" -ForegroundColor Yellow
}

$errLog1 = Join-Path $scanDir 'docs\ERRORS_AND_FAILURES.md'
$errLog2 = Join-Path $scanDir 'ERRORS_AND_FAILURES.md'
if (-not (Test-Path -LiteralPath $errLog1) -and -not (Test-Path -LiteralPath $errLog2)) {
    Write-Host "[gate] ℹ️ База ошибок docs/ERRORS_AND_FAILURES.md отсутствует (создавайте через record-failure.ps1 при первом сбое)" -ForegroundColor DarkYellow
}

# --- Syntax & BOM checks ------------------------------------------------

$syntaxFailures = @()

if (-not $SkipSyntax) {
    $python = Get-Command python -ErrorAction SilentlyContinue
    $node = Get-Command node -ErrorAction SilentlyContinue
    $bashSh = @("C:\Program Files\Git\bin\sh.exe", "C:\Program Files\Git\usr\bin\sh.exe") |
        Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

    foreach ($name in $files) {
        $full = Join-Path $scanDir $name
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { continue }
        $ext = [System.IO.Path]::GetExtension($name).ToLowerInvariant()

        # SYNTAX-BOM: запрет UTF-8 BOM в Linux shell (.sh, S9*) и Android (.kl, .idc)
        if ($ext -in @('.sh', '.kl', '.idc') -or $name -match '(^|/|\\)S\d{2}') {
            try {
                $stream = [System.IO.File]::OpenRead($full)
                $hdr = New-Object byte[] 3
                $read = $stream.Read($hdr, 0, 3)
                $stream.Dispose()
                if ($read -eq 3 -and $hdr[0] -eq 0xEF -and $hdr[1] -eq 0xBB -and $hdr[2] -eq 0xBF) {
                    $syntaxFailures += "bom: $name (UTF-8 BOM breaks Linux shebangs and Android .kl/.idc parsers; save as UTF-8 without BOM)"
                }
            } catch {}
        }

        # PS-002: .ps1 обязан быть UTF-8 с BOM (иначе PowerShell 5.1 читает его как ANSI и ломает парсер на кириллице)
        if ($ext -eq '.ps1') {
            try {
                $stream = [System.IO.File]::OpenRead($full)
                $hdr = New-Object byte[] 3
                $read = $stream.Read($hdr, 0, 3)
                $stream.Dispose()
                if (-not ($read -eq 3 -and $hdr[0] -eq 0xEF -and $hdr[1] -eq 0xBB -and $hdr[2] -eq 0xBF)) {
                    $syntaxFailures += "bom: $name (.ps1 without UTF-8 BOM is read as ANSI by PowerShell 5.1; Cyrillic breaks the parser. Re-save as UTF-8 with BOM)"
                }
            } catch {}
        }

        if ($ext -eq '.py' -and $python) {            & $python.Source -m py_compile $full 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { $syntaxFailures += "python: $name" }
        }
        elseif ($ext -eq '.js' -and $node) {
            $null = & $node.Source --check $full 2>&1
            if ($LASTEXITCODE -ne 0) { $syntaxFailures += "node: $name" }
        }
        elseif ($ext -eq '.ps1') {
            try {
                $parseErrors = $null
                $psContent = [System.IO.File]::ReadAllText($full, [System.Text.Encoding]::UTF8)
                [void][System.Management.Automation.Language.Parser]::ParseInput($psContent, $name, [ref]$null, [ref]$parseErrors)
                if ($parseErrors -and $parseErrors.Count -gt 0) {
                    $syntaxFailures += "powershell: $name ($($parseErrors[0].Message) at line $($parseErrors[0].Extent.StartLineNumber))"
                }
            } catch {
                $syntaxFailures += "powershell: $name ($($_))"
            }
        }
        elseif (($ext -eq '.sh' -or $name -match '(^|/)S\d{2}') -and $bashSh) {
            if ($name -match '(^|/)S\d{2}') {
                try {
                    $head = Get-Content -LiteralPath $full -TotalCount 1 -Encoding UTF8
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
        $full = Join-Path $scanDir $name
        if (-not (Test-Path -LiteralPath $full)) { continue }
        $text = [System.IO.File]::ReadAllText($full, [System.Text.Encoding]::UTF8)
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

# --- PATH-001: Mobile, C/C++, Java & PyInstaller Path Invariants -------
$pathFailures = @()
$exactTriggerNames = @('AndroidManifest.xml', 'apktool.yml', 'build.gradle', 'build.gradle.kts', 'CMakeLists.txt')
$triggerExts = @('.java', '.kt', '.kts', '.gradle', '.c', '.cc', '.cpp', '.cxx', '.h', '.hpp', '.spec')

$hasMobileOrNativeTriggers = $false
foreach ($f in $files) {
    $baseName = Split-Path $f -Leaf
    $ext = [System.IO.Path]::GetExtension($f).ToLowerInvariant()
    if ($exactTriggerNames -contains $baseName -or $triggerExts -contains $ext) {
        $hasMobileOrNativeTriggers = $true
        break
    }
}

if ($hasMobileOrNativeTriggers) {
    $fullScanDir = [System.IO.Path]::GetFullPath($scanDir)
    $hasNonAscii = [regex]::IsMatch($fullScanDir, '[^\x00-\x7F]')
    $hasCyrillic = [regex]::IsMatch($fullScanDir, '[\u0400-\u04FF\u0500-\u052F\u2DE0-\u2DFF\uA640-\uA69F]')
    $hasSpaces = [regex]::IsMatch($fullScanDir, '\s')
    
    if ($hasNonAscii -or $hasSpaces) {
        $reason = @()
        if ($hasCyrillic) { $reason += 'кириллица' }
        elseif ($hasNonAscii) { $reason += 'не-ASCII' }
        if ($hasSpaces) { $reason += 'пробелы' }
        $pathFailures += "PATH-001: путь '$fullScanDir' содержит $($reason -join ' + '). Android/apktool/aapt2/Gradle/C++/PyInstaller ломаются на таких путях. Перенесите проект в чистый ASCII-путь без пробелов."
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
foreach ($p in $pathFailures)   { Write-Host "  [FAIL] $p" -ForegroundColor Red }

$total = $findings.Count + $syntaxFailures.Count + $linkFailures.Count + $pathFailures.Count
if ($total -gt 0) {
    Write-Host ""
    Write-Host "SECURITY GATE FAILED: $total problem(s)." -ForegroundColor Red
    exit 1
}

Write-Host "SECURITY GATE PASSED ($($files.Count) files, $($excused.Count) excused)." -ForegroundColor Green
exit 0
