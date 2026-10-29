param(
    [string]$ProjectPath = (Get-Location).Path,
    [string]$NextGoal = ""
)

$ErrorActionPreference = "Continue"

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
    $diffFiles = (& git -C $ProjectPath diff --name-only HEAD~1 2>$null)
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
$stackInfo = "Не указан"
$recentChanges = "Продолжение разработки"
$pendingTasks = @()

if (Test-Path $stateFile) {
    $stateLines = Get-Content $stateFile -Encoding UTF8
    $inStack = $false
    $inChanges = $false
    $inNext = $false

    foreach ($line in $stateLines) {
        if ($line -match "## 2\. Стек Технологий") { $inStack = $true; continue }
        if ($line -match "## 3\." -or $line -match "## 4\.") { $inStack = $false }
        if ($line -match "## 5\. История Изменений") { $inChanges = $true; continue }
        if ($line -match "## 6\." -or $line -match "## 7\.") { $inChanges = $false; $inNext = $true; continue }

        if ($inStack -and $line -match "^- \*\*") {
            $stackInfo = $line.Replace("- **", "").Replace("**", "").Trim()
        }
        if ($inChanges -and $line -match "^### \[" -and $recentChanges -eq "Продолжение разработки") {
            $recentChanges = $line.Replace("### ", "").Trim()
        }
        if ($inNext -and $line -match "^\d+\.\s+(.*)") {
            $pendingTasks += $matches[1]
        }
    }
}

$taskGoal = if ($NextGoal) { $NextGoal } elseif ($pendingTasks.Count -gt 0) { $pendingTasks[0] } else { "Продолжить реализацию следующего этапа" }

# Генерация готового промпта для нового диалога
$handoffPrompt = @"
Привет! Мы продолжаем работу над проектом '$projectName' в папке: $ProjectPath
Ветка Git: $branch | Последний коммит: $lastCommit
Задача на текущую сессию: $taskGoal

Пожалуйста, первым делом прочитай PROJECT_STATE.md для загрузки полной памяти проекта и подтверди готовность к задаче.
"@

# Сохранение в .agents/HANDOFF.md
$handoffFile = Join-Path $agentsDir "HANDOFF.md"
$handoffDoc = @"
# Контекст передачи проекта в новый диалог (Handoff)

- **Проект**: $projectName ($ProjectPath)
- **Дата формирования**: $((Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))
- **Ветка Git**: $branch
- **Последний коммит**: $lastCommit

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
Write-Host "`n" + ("=" * 70) -ForegroundColor Cyan
Write-Host "СКОПИРУЙТЕ ЭТОТ ПРОМПТ В НОВЫЙ ДИАЛОГ ДЛЯ МГНОВЕННОГО ВХОДА В КОНТЕКСТ:" -ForegroundColor Yellow
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host $handoffPrompt -ForegroundColor White
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host ""
