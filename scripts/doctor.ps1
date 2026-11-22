[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$ProjectPath = (Get-Location).Path,
    [switch]$Harness
)

$ErrorActionPreference = "Continue"
$env:PYTHONIOENCODING = "utf-8"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if ($ProjectPath -and $ProjectPath.StartsWith("-")) {
    if ($ProjectPath -eq "-Harness") {
        $Harness = $true
    }
    $ProjectPath = (Get-Location).Path
}

if ($Harness) {
    $harnessScript = Join-Path $PSScriptRoot "audit-harness.ps1"
    if (Test-Path -LiteralPath $harnessScript) {
        & $harnessScript -ProjectPath $ProjectPath
        exit $LASTEXITCODE
    }
}

if ($ProjectPath -and (Test-Path -LiteralPath $ProjectPath)) {
    $ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path
}

Write-Host "`n=== [Project Guardian] Диагностика Окружения и Проекта (Doctor) ===" -ForegroundColor Cyan
Write-Host "Проект: $ProjectPath`n"

$allOk = $true

function Report-Item {
    param(
        [string]$Title,
        [string]$Status, # "OK", "WARN", "FAIL"
        [string]$Details
    )
    switch ($Status) {
        "OK"   { Write-Host "  [OK]   " -ForegroundColor Green -NoNewline }
        "WARN" { Write-Host "  [WARN] " -ForegroundColor Yellow -NoNewline }
        "FAIL" { Write-Host "  [FAIL] " -ForegroundColor Red -NoNewline }
    }
    Write-Host "$Title" -ForegroundColor White -NoNewline
    if ($Details) {
        Write-Host " -> $Details" -ForegroundColor Gray
    } else {
        Write-Host ""
    }
}

# 1. Проверка системных инструментов
Write-Host "1. Системные инструменты и рантаймы:" -ForegroundColor Cyan

try {
    $gitVer = (& git --version 2>$null)
    if ($gitVer) { Report-Item "Git" "OK" $gitVer.Trim() }
    else { Report-Item "Git" "FAIL" "Не найден в PATH"; $script:allOk = $false }
} catch { Report-Item "Git" "FAIL" "Ошибка вызова"; $script:allOk = $false }

$gitBashPath = "C:\Program Files\Git\bin\bash.exe"
if (Test-Path -LiteralPath $gitBashPath) {
    Report-Item "Git Bash" "OK" $gitBashPath
} else {
    Report-Item "Git Bash" "WARN" "Не найден по стандартному пути $gitBashPath"
}

try {
    $pyVer = (& python --version 2>&1)
    if ($LASTEXITCODE -eq 0 -and $pyVer) { Report-Item "Python" "OK" $pyVer.Trim() }
    else { Report-Item "Python" "WARN" "Не обнаружен в PATH" }
} catch { Report-Item "Python" "WARN" "Не обнаружен в PATH" }

try {
    $nodeVer = (& node --version 2>$null)
    if ($nodeVer) { Report-Item "Node.js" "OK" $nodeVer.Trim() }
    else { Report-Item "Node.js" "WARN" "Не обнаружен в PATH" }
} catch { Report-Item "Node.js" "WARN" "Не обнаружен" }

try {
    $uvVer = (& uv --version 2>$null)
    if ($uvVer) { Report-Item "uv package manager" "OK" $uvVer.Trim() }
} catch {}

try {
    $pytestVer = (& python -m pytest --version 2>&1)
    if ($LASTEXITCODE -eq 0 -and $pytestVer) { Report-Item "pytest runner" "OK" ($pytestVer -join " ").Trim() }
    else { Report-Item "pytest runner" "WARN" "Не установлен (auto-ensure в run-tests.ps1 установит при запуске)" }
} catch { Report-Item "pytest runner" "WARN" "Не обнаружен" }

# 2. Состояние Git-репозитория
Write-Host "`n2. Состояние Git репозитория:" -ForegroundColor Cyan
$isGit = $false
try {
    $gitCheck = & git -C $ProjectPath rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -eq 0 -and $gitCheck -and $gitCheck.Trim() -eq "true") {
        $isGit = $true
    }
} catch { $isGit = $false }

if ($isGit) {
    $branch = (& git -C $ProjectPath rev-parse --abbrev-ref HEAD 2>$null).Trim()
    Report-Item "Git репозиторий" "OK" "Текущая ветка: $branch"

    $remotes = (& git -C $ProjectPath remote -v 2>$null)
    if ($remotes) {
        $originUrl = (& git -C $ProjectPath remote get-url origin 2>$null)
        Report-Item "Git Remote (origin)" "OK" $originUrl

        try {
            $counts = (& git -C $ProjectPath rev-list --left-right --count "HEAD...origin/$branch" 2>$null)
            if ($counts) {
                $ahead, $behind = $counts.Trim().Split("`t")
                if ([int]$ahead -eq 0 -and [int]$behind -eq 0) {
                    Report-Item "Синхронизация" "OK" "Ветка полностью синхронизирована с origin"
                } else {
                    Report-Item "Синхронизация" "WARN" "Локально впереди: $ahead, отстает: $behind"
                }
            }
        } catch {}
    } else {
        Report-Item "Git Remote" "WARN" "Удаленный репозиторий не настроен"
    }

    $statusPorcelain = (& git -C $ProjectPath status --porcelain 2>$null)
    if ($statusPorcelain) {
        $changedCount = ($statusPorcelain | Measure-Object).Count
        Report-Item "Рабочее дерево" "WARN" "Есть незакоммиченные файлы: $changedCount"
    } else {
        Report-Item "Рабочее дерево" "OK" "Чистое, все изменения закоммичены"
    }
} else {
    Report-Item "Git репозиторий" "WARN" "Папка не является git-репозиторием"
}

# 3. Состояние Project Guardian компонентов
Write-Host "`n3. Компоненты Project Guardian:" -ForegroundColor Cyan

$stateFile = Join-Path $ProjectPath "PROJECT_STATE.md"
if (Test-Path -LiteralPath $stateFile) {
    $mtime = (Get-Item -LiteralPath $stateFile).LastWriteTime.ToString("yyyy-MM-dd HH:mm")
    Report-Item "Память проекта (PROJECT_STATE.md)" "OK" "Обновлен: $mtime"
} else {
    Report-Item "Память проекта (PROJECT_STATE.md)" "WARN" "Файл памяти отсутствует"
}

# База ошибок (docs/ERRORS_AND_FAILURES.md)
$errFile = Join-Path $ProjectPath "docs\ERRORS_AND_FAILURES.md"
if (-not (Test-Path -LiteralPath $errFile)) {
    $errFile = Join-Path $ProjectPath "ERRORS_AND_FAILURES.md"
}
if (Test-Path -LiteralPath $errFile) {
    $errText = [System.IO.File]::ReadAllText($errFile, [System.Text.Encoding]::UTF8)
    $incCount = ([regex]::Matches($errText, '### \[Инцидент ')).Count
    Report-Item "База ошибок (ERRORS_AND_FAILURES.md)" "OK" "Зафиксировано инцидентов: $incCount"
} else {
    Report-Item "База ошибок (ERRORS_AND_FAILURES.md)" "WARN" "Файл отсутствует (создается через record-failure.ps1)"
}

# Рекомендации (AGENT_RECOMMENDATIONS.md)
$recFile = Join-Path $ProjectPath "AGENT_RECOMMENDATIONS.md"
if (Test-Path -LiteralPath $recFile) {
    $recText = [System.IO.File]::ReadAllText($recFile, [System.Text.Encoding]::UTF8)
    $openRecs = ([regex]::Matches($recText, '\[ \]\s*ТРЕБУЕТ ВНЕДРЕНИЯ')).Count
    $doneRecs = ([regex]::Matches($recText, '\[x\]\s*ВЫПОЛНЕНО')).Count
    if ($doneRecs -gt 0) {
        Report-Item "Рекомендации (AGENT_RECOMMENDATIONS.md)" "FAIL" "Неархивированных [x]: $doneRecs, открытых [ ]: $openRecs (перенесите [x] в docs/APPLIED_RECOMMENDATIONS.md)"
        $script:allOk = $false
    } elseif ($openRecs -gt 0) {
        Report-Item "Рекомендации (AGENT_RECOMMENDATIONS.md)" "WARN" "Открытых задач [ ] ТРЕБУЕТ ВНЕДРЕНИЯ: $openRecs"
    } else {
        Report-Item "Рекомендации (AGENT_RECOMMENDATIONS.md)" "OK" "Все рекомендации обработаны"
    }
} else {
    Report-Item "Рекомендации (AGENT_RECOMMENDATIONS.md)" "OK" "Открытых входящих рекомендаций нет"
}

$subProjects = @(Get-ChildItem -LiteralPath $ProjectPath -Directory -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -notmatch '^(\.git|\.backups|node_modules|\.venv|venv|scratch|graphify-out)$' -and
    (Test-Path -LiteralPath (Join-Path $_.FullName "PROJECT_STATE.md"))
})
if ($subProjects.Count -gt 0) {
    Report-Item "Составной воркспейс" "OK" "Обнаружены подпроекты ($($subProjects.Count)): $($subProjects.Name -join ', ')"
}

$backupDir = Join-Path $ProjectPath ".backups"
if (Test-Path -LiteralPath $backupDir) {
    $cps = Get-ChildItem -LiteralPath $backupDir -Directory -ErrorAction SilentlyContinue
    $totalBackups = ($cps | Measure-Object).Count
    $releases = ($cps | Where-Object { $_.Name -like "*release*" -or $_.Name -like "firmware_success_*" } | Measure-Object).Count
    Report-Item "Резервные копии (.backups/)" "OK" "Всего: $totalBackups (из них релизов/прошивок: $releases)"
} else {
    Report-Item "Резервные копии (.backups/)" "WARN" "Папка еще не создана"
}

$graphifyDir = Join-Path $ProjectPath "graphify-out"
if (Test-Path -LiteralPath $graphifyDir) {
    $graphJson = Join-Path $graphifyDir "graph.json"
    if (Test-Path -LiteralPath $graphJson) {
        $gmtime = (Get-Item -LiteralPath $graphJson).LastWriteTime.ToString("yyyy-MM-dd HH:mm")
        Report-Item "Граф знаний (graphify)" "OK" "Граф построен ($gmtime)"
    } else {
        Report-Item "Граф знаний (graphify)" "WARN" "Папка есть, но graph.json не найден"
    }
} else {
    Report-Item "Граф знаний (graphify)" "WARN" "Папка graphify-out/ не найдена (создастся автоматически при checkpoint.ps1)"
}

# Security Gate
$secGateScript = Join-Path $PSScriptRoot "security-gate.ps1"
if (Test-Path -LiteralPath $secGateScript) {
    Write-Host "`n4. Экспресс-проверка Security Gate:" -ForegroundColor Cyan
    try {
        & $secGateScript -ProjectPath $ProjectPath
        if ($LASTEXITCODE -eq 0) {
            Report-Item "Security Gate" "OK" "Все проверки безопасности пройдены"
        } else {
            Report-Item "Security Gate" "FAIL" "Обнаружены проблемы безопасности!"
            $script:allOk = $false
        }
    } catch {
        Report-Item "Security Gate" "WARN" "Ошибка при выполнении security-gate: $_"
    }
}

Write-Host ("`n" + ("=" * 60))
if ($allOk) {
    Write-Host "ИТОГ: Проект в отличном состоянии, блокеров нет. Готов к работе!" -ForegroundColor Green
} else {
    Write-Host "ИТОГ: Обнаружены предупреждения или ошибки. Проверьте вывод выше." -ForegroundColor Yellow
}
Write-Host ""
