<#
.SYNOPSIS
    Генератор межпроектных рекомендаций (AGENT_RECOMMENDATIONS.md).
.DESCRIPTION
    Добавляет стандартизированную запись '### [ ] ТРЕБУЕТ ВНЕДРЕНИЯ: <Title>'
    в AGENT_RECOMMENDATIONS.md целевого проекта или базового скилла (E:\Projects\Skill),
    соблюдая правило строгой изоляции воркспейсов (Rule 11).
.PARAMETER Title
    Краткое название рекомендации или правила.
.PARAMETER TargetProject
    Путь к целевому проекту (если не указан или передан -ToSkill, пишет в E:\Projects\Skill).
.PARAMETER ToSkill
    Отправить рекомендацию напрямую в базовый скилл Project Guardian (E:\Projects\Skill).
.PARAMETER SourceProject
    Имя проекта-источника (по умолчанию текущая папка).
.PARAMETER Problem
    Симптом и первопричина проблемы.
.PARAMETER Solution
    Предлагаемое решение, сниппет кода или правило.
.PARAMETER Verification
    Как проверить внедрение (тесты, security-gate.ps1).
.EXAMPLE
    & "C:\Users\Salomanov\.gemini\config\skills\project-guardian\scripts\add-recommendation.ps1" -ToSkill -Title "Новое правило" -Problem "Описание" -Solution "Решение"
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string[]]$Title,

    [Parameter(Mandatory=$false)]
    [string]$TargetProject = "",

    [Parameter(Mandatory=$false)]
    [switch]$ToSkill = $false,

    [Parameter(Mandatory=$false)]
    [string]$SourceProject = (Split-Path (Get-Location).Path -Leaf),

    [Parameter(Mandatory=$false)]
    [string[]]$Problem = @("Не указана"),

    [Parameter(Mandatory=$false)]
    [string[]]$Solution = @("Не указано"),

    [Parameter(Mandatory=$false)]
    [string[]]$Verification = @("security-gate.ps1 возвращает exit code 0"),

    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$ExtraArgs
)

$ErrorActionPreference = "Stop"
$env:PYTHONIOENCODING = "utf-8"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if ($ExtraArgs) {
    $allTitle = @($Title) + @($ExtraArgs)
    $Title = ($allTitle -join " ").Trim()
} elseif ($Title -is [array]) {
    $Title = ($Title -join " ").Trim()
}
if ($Problem -is [array]) { $Problem = ($Problem -join " ").Trim() }
if ($Solution -is [array]) { $Solution = ($Solution -join " ").Trim() }
if ($Verification -is [array]) { $Verification = ($Verification -join " ").Trim() }

if ($ToSkill -or [string]::IsNullOrWhiteSpace($TargetProject)) {
    if (Test-Path -LiteralPath "E:\Projects\Skill") {
        $TargetProject = "E:\Projects\Skill"
    } else {
        $TargetProject = Split-Path $PSScriptRoot -Parent
    }
}

if (-not (Test-Path -LiteralPath $TargetProject)) {
    Write-Error "Целевой проект не найден: $TargetProject"
    exit 1
}

$TargetProject = (Resolve-Path -LiteralPath $TargetProject).Path
$recFile = Join-Path $TargetProject "AGENT_RECOMMENDATIONS.md"
$targetName = Split-Path $TargetProject -Leaf
$timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm")

if (-not (Test-Path -LiteralPath $recFile)) {
    $header = "# Рекомендации по улучшению проекта ($targetName)`n`n> Данный файл содержит входящие межпроектные рекомендации (Advisory Mode / Rule 11).`n"
    [System.IO.File]::WriteAllText($recFile, $header, [System.Text.Encoding]::UTF8)
} else {
    $existing = [System.IO.File]::ReadAllText($recFile, [System.Text.Encoding]::UTF8)
    if ($existing -match '^\s*\*Все входящие рекомендации успешно внедрены') {
        $header = "# Рекомендации по улучшению проекта ($targetName)`n`n> Данный файл содержит входящие межпроектные рекомендации (Advisory Mode / Rule 11).`n"
        [System.IO.File]::WriteAllText($recFile, $header, [System.Text.Encoding]::UTF8)
    }
}

$entry = @"

---

### [ ] ТРЕБУЕТ ВНЕДРЕНИЯ: $Title
- **Источник**: Проект «$SourceProject» (дата: $timestamp).
- **Проблема**: $Problem
- **Решение**: $Solution
- **Верификация**: $Verification
"@

[System.IO.File]::AppendAllText($recFile, $entry, [System.Text.Encoding]::UTF8)
Write-Host "[Project Guardian] ✅ Рекомендация добавлена в: $recFile" -ForegroundColor Green
Write-Host "  Задача: [ ] ТРЕБУЕТ ВНЕДРЕНИЯ: $Title" -ForegroundColor Cyan
