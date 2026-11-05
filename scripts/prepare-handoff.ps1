param(
    [string]$ProjectPath = (Get-Location).Path,
    [string]$SubProject = "",
    [string]$NextGoal = ""
)

$ErrorActionPreference = "Continue"
$env:PYTHONIOENCODING = "utf-8"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# 0. Нормализация пути и поддержка подпроектов
if ($ProjectPath -and (Test-Path $ProjectPath)) {
    $ProjectPath = (Resolve-Path $ProjectPath).Path
}

if ($SubProject) {
    $cand = Join-Path $ProjectPath $SubProject
    if (Test-Path $cand) {
        $ProjectPath = (Resolve-Path $cand).Path
    }
}

Write-Host "`n=== [Project Guardian] Подготовка передачи контекста в новый диалог ===" -ForegroundColor Cyan
Write-Host "Проект: $ProjectPath"

$agentsDir = Join-Path $ProjectPath ".agents"
if (-not (Test-Path $agentsDir)) {
    New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
}

$projectName = Split-Path $ProjectPath -Leaf

# Получение данных Git
$branch = "main"
$lastCommit = "нет коммитов"
$changedFiles = @()

try {
    $branch = (& git -C $ProjectPath rev-parse --abbrev-ref HEAD 2>$null).Trim()
    $lastCommit = (& git -C $ProjectPath log -1 --pretty=format:"%s (%h)" 2>$null)
    $diffFiles = (& git -C $ProjectPath diff-tree --no-commit-id --name-only -r HEAD 2>$null)
    if ($diffFiles) { $changedFiles = $diffFiles }
    $uncommitted = (& git -C $ProjectPath status --porcelain 2>$null)
    if ($uncommitted) {
        foreach ($line in $uncommitted) {
            $f = $line.Substring(3).Trim()
            if ($changedFiles -notcontains $f) { $changedFiles += "$f (незакоммичен)" }
        }
    }
} catch {}

# Чтение PROJECT_STATE.md
$stateFile = Join-Path $ProjectPath "PROJECT_STATE.md"
$stackItems = @()
$stackInfo = "Не указан"
$recentChanges = "Продолжение разработки"
$pendingTasks = @()

if (Test-Path $stateFile) {
    $stateLines = Get-Content $stateFile -Encoding UTF8
    $inStack = $false
    $inChanges = $false
    $inNext = $false

    foreach ($line in $stateLines) {
        # Стек технологий (поддерживает любой номер раздела)
        if ($line -match "## (?:\d+\.\s*)?Стек Технологий") { 
            $inStack = $true; $inChanges = $false; $inNext = $false; continue 
        }
        # История изменений
        if ($line -match "## (?:\d+\.\s*)?История Изменений") { 
            $inChanges = $true; $inStack = $false; $inNext = $false; continue 
        }
        # Следующие шаги
        if ($line -match "## (?:\d+\.\s*)?Следующие Шаги") { 
            $inNext = $true; $inStack = $false; $inChanges = $false; continue 
        }
        # Сброс флагов при начале любого другого h2 раздела
        if ($line -match "^##\s+\d+\.") {
            $inStack = $false
            $inChanges = $false
        }

        if ($inStack -and $line -match "^- \*\*") {
            $stackItems += $line.Replace("- **", "").Replace("**", "").Trim()
        }
        if ($inChanges -and $line -match "^### \[" -and $recentChanges -eq "Продолжение разработки") {
            $recentChanges = $line.Replace("### ", "").Trim()
        }
        if ($inNext -and $line -match "^\d+\.\s+(.*)") {
            $pendingTasks += $matches[1]
        }
    }

    if ($stackItems.Count -gt 0) {
        $stackInfo = $stackItems -join " | "
    }
}

$taskGoal = if ($NextGoal) { $NextGoal } elseif ($pendingTasks.Count -gt 0) { $pendingTasks[0] } else { "Продолжить реализацию следующего этапа" }

# Генерация готового промпта для нового диалога
$handoffPrompt = @"
Привет! Мы продолжаем работу над проектом '$projectName' в папке: $ProjectPath
Стек: $stackInfo | Ветка Git: $branch | Последний коммит: $lastCommit
Контекст изменений: $recentChanges
Задача на текущую сессию: $taskGoal

Пожалуйста, первым делом прочитай PROJECT_STATE.md для загрузки полной памяти проекта и подтверди готовность к задаче.
"@

# Сохранение в .agents/HANDOFF.md
$handoffFile = Join-Path $agentsDir "HANDOFF.md"
$handoffDoc = @"
# Контекст передачи проекта в новый диалог (Handoff)

- **Проект**: $projectName ($ProjectPath)
- **Дата формирования**: $((Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))
- **Стек**: $stackInfo
- **Ветка Git**: $branch
- **Последний коммит**: $lastCommit
- **Последние изменения**: $recentChanges

---

## Готовый промпт для вставки в новый чат:
```text
$handoffPrompt
```

---

## Затронутые файлы:
"@

if ($changedFiles.Count -gt 0) {
    foreach ($cf in $changedFiles) {
        $handoffDoc += "`n- $cf"
    }
} else {
    $handoffDoc += "`n*(Все файлы зафиксированы в чистом состоянии)*"
}

$handoffDoc += "`n`n## Следующие шаги:`n"
if ($pendingTasks.Count -gt 0) {
    for ($i = 0; $i -lt $pendingTasks.Count; $i++) {
        $handoffDoc += "$($i + 1). $($pendingTasks[$i])`n"
    }
} else {
    $handoffDoc += "1. $taskGoal`n"
}

[System.IO.File]::WriteAllText($handoffFile, $handoffDoc, [System.Text.Encoding]::UTF8)

Write-Host "[OK] Файл контекста сохранен: $handoffFile" -ForegroundColor Green
Write-Host ("`n" + ("=" * 70)) -ForegroundColor Cyan
Write-Host "СКОПИРУЙТЕ ЭТОТ ПРОМПТ В НОВЫЙ ДИАЛОГ ДЛЯ МГНОВЕННОГО ВХОДА В КОНТЕКСТ:" -ForegroundColor Yellow
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host $handoffPrompt -ForegroundColor White
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host ""
