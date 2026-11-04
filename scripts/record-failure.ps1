<#
.SYNOPSIS
    Автоматическая немедленная фиксация сбоев, аппаратных граблей и инцидентов.
.DESCRIPTION
    Записывает ошибку в docs/ERRORS_AND_FAILURES.md, запускает graphify для обновления
    графа знаний, создает защитную контрольную точку в .backups и коммитит локально.
    В составных воркспейсах автоматически изолирует запись в целевой подпроект.
    Пуш в remote не выполняется (только явным -Push у checkpoint.ps1).
.PARAMETER Title
    Краткое название сбоя/ошибки.
.PARAMETER Symptom
    Симптом и ущерб (что наблюдалось, поведение системы).
.PARAMETER RootCause
    Аппаратная или программная первопричина (Root Cause).
.PARAMETER Solution
    Решение, правило предотвращения или способ восстановления.
.PARAMETER ProjectPath
    Путь к проекту (по умолчанию текущая директория).
.PARAMETER SubProject
    Явное указание подпроекта в составном воркспейсе / монорепозитории.
.PARAMETER NoCheckpoint
    Не запускать автоматический checkpoint после записи.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Title,

    [Parameter(Mandatory=$false)]
    [string]$Symptom = "Не указан",

    [Parameter(Mandatory=$false)]
    [string]$RootCause = "Не указана",

    [Parameter(Mandatory=$false)]
    [string]$Solution = "Не указано",

    [Parameter(Mandatory=$false)]
    [string]$ProjectPath = (Get-Location).Path,

    [Parameter(Mandatory=$false)]
    [string]$SubProject = "",

    [Parameter(Mandatory=$false)]
    [switch]$NoCheckpoint
)

$ErrorActionPreference = "Stop"

# 0. Нормализация пути и автоопределение подпроекта в составных воркспейсах
if ($ProjectPath -and (Test-Path $ProjectPath)) {
    $ProjectPath = (Resolve-Path $ProjectPath).Path
}

if ($SubProject) {
    $candidateSub = Join-Path $ProjectPath $SubProject
    if (Test-Path $candidateSub) {
        $ProjectPath = (Resolve-Path $candidateSub).Path
        Write-Host "[Project Guardian] 🎯 Выбран подпроект: $ProjectPath" -ForegroundColor Cyan
    } else {
        Write-Warning "Указанный подпроект '$SubProject' не найден в $ProjectPath"
    }
} else {
    # Проверяем, является ли $ProjectPath контейнером нескольких подпроектов (каждый со своим PROJECT_STATE.md)
    $subProjects = @(Get-ChildItem -Path $ProjectPath -Directory -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -notmatch '^(\.git|\.backups|node_modules|\.venv|venv|scratch)$' -and
        (Test-Path (Join-Path $_.FullName "PROJECT_STATE.md"))
    })

    if ($subProjects.Count -gt 0) {
        $detectedSub = $null

        # 1. Поиск по упоминанию имени подпроекта в названии или описании сбоя
        foreach ($sp in $subProjects) {
            $spName = $sp.Name
            if ($Title -match "(?i)\b$spName\b" -or $Symptom -match "(?i)\b$spName\b" -or $RootCause -match "(?i)\b$spName\b") {
                $detectedSub = $sp.FullName
                break
            }
        }

        # 2. Поиск по упоминаемым именам файлов (.py, .js, .ts, .sh, .cs, .php, .html, .json)
        if (-not $detectedSub) {
            $fileMatches = [regex]::Matches("$Title $Symptom $RootCause $Solution", '([A-Za-z0-9_-]+\.(?:py|js|ts|sh|cs|php|html|css|json|ino|cpp|h))')
            if ($fileMatches.Count -gt 0) {
                $mentionedFiles = $fileMatches | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
                foreach ($sp in $subProjects) {
                    foreach ($mf in $mentionedFiles) {
                        if (Test-Path (Join-Path $sp.FullName $mf)) {
                            $detectedSub = $sp.FullName
                            break
                        }
                    }
                    if ($detectedSub) { break }
                }
            }
        }

        # 3. Поиск по незакоммиченным файлам в Git
        if (-not $detectedSub) {
            try {
                $gitStatus = & git -C $ProjectPath status --porcelain 2>$null
                if ($gitStatus) {
                    $subHits = @{}
                    foreach ($sp in $subProjects) {
                        $prefixSlash = "$($sp.Name)/"
                        $prefixBack = "$($sp.Name)\"
                        $matchCount = @($gitStatus | Where-Object { 
                            $trimmed = $_.Substring(3).Trim()
                            $trimmed.StartsWith($prefixSlash) -or $trimmed.StartsWith($prefixBack)
                        }).Count
                        if ($matchCount -gt 0) {
                            $subHits[$sp.FullName] = $matchCount
                        }
                    }
                    if ($subHits.Keys.Count -eq 1) {
                        $detectedSub = $subHits.Keys | Select-Object -First 1
                    }
                }
            } catch {}
        }

        if ($detectedSub) {
            $ProjectPath = $detectedSub
            $spName = Split-Path $ProjectPath -Leaf
            Write-Host "[Project Guardian] 🎯 Автоопределение: инцидент относится к подпроекту '$spName'." -ForegroundColor Cyan
            Write-Host "   Файл ошибок фиксируется в: $ProjectPath\docs\ERRORS_AND_FAILURES.md" -ForegroundColor Gray
        } else {
            Write-Host "[Project Guardian] ℹ️ Составной воркспейс с подпроектами: $($subProjects.Name -join ', ')" -ForegroundColor DarkCyan
            Write-Host "   Для изолированной записи ошибок передайте: -ProjectPath <путь> или -SubProject <имя>" -ForegroundColor Gray
        }
    }
}

Write-Host "`n=== [Project Guardian] ⚠️ Немедленная фиксация инцидента/ошибки ===" -ForegroundColor Yellow
Write-Host "Проект: $ProjectPath"
Write-Host "Ошибка: $Title"

# 1. Поиск или создание файла базы ошибок
$docsDir = Join-Path $ProjectPath "docs"
$errorFile = Join-Path $docsDir "ERRORS_AND_FAILURES.md"

if (-not (Test-Path $errorFile)) {
    # Проверяем в корне
    $rootErrorFile = Join-Path $ProjectPath "ERRORS_AND_FAILURES.md"
    if (Test-Path $rootErrorFile) {
        $errorFile = $rootErrorFile
    } else {
        if (-not (Test-Path $docsDir)) {
            New-Item -ItemType Directory -Path $docsDir -Force | Out-Null
        }
        $header = "# База знаний ошибок, граблей и неудачных экспериментов (FAILURE LOG)`n> **Назначение файла**: Полный реестр всех ошибочных решений, тупиковых гипотез и проверенных антипаттернов.`n> **Правило разработчика**: ПЕРЕД любым изменением пинов, регистров или архитектуры ОБЯЗАТЕЛЬНО свериться с этим файлом!`n`n---`n`n"
        [System.IO.File]::WriteAllText($errorFile, $header, [System.Text.Encoding]::UTF8)
        Write-Host "[OK] Создан новый файл базы ошибок: $errorFile" -ForegroundColor Green
    }
}

# 2. Формирование записи ошибки
$timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
$entry = "`n---`n`n### [Инцидент $timestamp] $Title`n- **Симптом и ущерб**: $Symptom`n- **Причина (Root Cause)**: $RootCause`n- **Решение и правило**: $Solution`n"

[System.IO.File]::AppendAllText($errorFile, $entry, [System.Text.Encoding]::UTF8)
Write-Host "[OK] Инцидент зафиксирован в $errorFile" -ForegroundColor Green

# 3. Автоматический запуск чекпоинта и актуализация graphify
if (-not $NoCheckpoint) {
    $checkpointScript = Join-Path $PSScriptRoot "checkpoint.ps1"
    if (Test-Path $checkpointScript) {
        Write-Host "`n[Project Guardian] Запуск авто-чекпоинта и актуализации graphify..." -ForegroundColor Cyan
        & $checkpointScript -ProjectPath $ProjectPath -Message "failure: $Title"
    } else {
        Write-Warning "Скрипт checkpoint.ps1 не найден: $checkpointScript"
    }
}
