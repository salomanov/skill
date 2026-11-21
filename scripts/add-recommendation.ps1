<#
.SYNOPSIS
    Генератор межпроектных рекомендаций (AGENT_RECOMMENDATIONS.md).
.DESCRIPTION
    Добавляет стандартизированную запись '### [ ] ТРЕБУЕТ ВНЕДРЕНИЯ: <Title>'
    в AGENT_RECOMMENDATIONS.md целевого проекта или профильного скилла,
    соблюдая правило строгой изоляции воркспейсов (Rule 11).
.PARAMETER Title
    Краткое название рекомендации или правила.
.PARAMETER TargetProject
    Путь к целевому проекту на диске.
.PARAMETER Skill
    Имя целевого скилла (например: router-ops, tasmota-pro, scan-to-epub-pro, project-guardian).
    Автоматически находит директорию скилла в ~/.gemini/config/skills/<Skill> или локальных папках.
.PARAMETER ToSkill
    (Устаревший алиас) Отправить рекомендацию напрямую в базовый скилл Project Guardian (E:\Projects\Skill).
.PARAMETER SourceProject
    Имя проекта-источника (по умолчанию текущая папка).
.PARAMETER Problem
    Симптом и первопричина проблемы.
.PARAMETER Solution
    Предлагаемое решение, сниппет кода или правило.
.PARAMETER Verification
    Как проверить внедрение (тесты, security-gate.ps1).
.EXAMPLE
    # Рекомендация для профильного скилла роутеров:
    & "scripts\add-recommendation.ps1" -Skill router-ops -Title "Новый профиль" -Problem "..." -Solution "..."

    # Рекомендация для мета-скилла Project Guardian:
    & "scripts\add-recommendation.ps1" -Skill project-guardian -Title "Новое мета-правило" -Problem "..." -Solution "..."

    # Рекомендация для внешнего проекта:
    & "scripts\add-recommendation.ps1" -TargetProject "E:\Projects\Router_api" -Title "Дедлок" -Problem "..." -Solution "..."
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string[]]$Title,

    [Parameter(Mandatory=$false)]
    [string]$TargetProject = "",

    [Parameter(Mandatory=$false)]
    [Alias("SkillName")]
    [string]$Skill = "",

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

# Разрешение целевого пути:
if ($Skill) {
    $Skill = $Skill.Trim()
    if ($Skill -in @("project-guardian", "skill", "Skill", "guardian")) {
        if (Test-Path -LiteralPath "E:\Projects\Skill") {
            $TargetProject = "E:\Projects\Skill"
        } else {
            $TargetProject = Split-Path $PSScriptRoot -Parent
        }
    } else {
        # 1. Поиск в глобальных скиллах (~/.gemini/config/skills/<Skill>)
        $globalSkillDir = Join-Path $HOME ".gemini\config\skills\$Skill"
        # 2. Поиск в локальном каталоге воркспейса (./skills/<Skill>)
        $localSkillDir = Join-Path (Get-Location).Path "skills\$Skill"

        if (Test-Path -LiteralPath $globalSkillDir) {
            $TargetProject = $globalSkillDir
        } elseif (Test-Path -LiteralPath $localSkillDir) {
            $TargetProject = $localSkillDir
        } else {
            # Если папка скилла еще не создана, используем глобальный каталог
            $TargetProject = $globalSkillDir
        }
    }
} elseif ($ToSkill) {
    if (Test-Path -LiteralPath "E:\Projects\Skill") {
        $TargetProject = "E:\Projects\Skill"
    } else {
        $TargetProject = Split-Path $PSScriptRoot -Parent
    }
} elseif ([string]::IsNullOrWhiteSpace($TargetProject)) {
    Write-Host "`n[ERROR] Не указан адресат рекомендации!" -ForegroundColor Red
    Write-Host "Укажите целевой скилл:   -Skill <SkillName>   (например: -Skill router-ops, -Skill project-guardian)" -ForegroundColor Yellow
    Write-Host "Или путь к проекту:      -TargetProject <Path> (например: -TargetProject `"E:\Projects\Router_api`")`n" -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path -LiteralPath $TargetProject)) {
    try {
        New-Item -ItemType Directory -Path $TargetProject -Force | Out-Null
    } catch {
        Write-Error "Целевой проект/скилл не найден и не может быть создан: $TargetProject"
        exit 1
    }
}

$TargetProject = (Resolve-Path -LiteralPath $TargetProject).Path
$recFile = Join-Path $TargetProject "AGENT_RECOMMENDATIONS.md"
$targetName = Split-Path $TargetProject -Leaf
$timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm")

$isSkillTarget = ($TargetProject -match '[\\/]skills[\\/]' -or $TargetProject -match '[\\/]Skill$')
$targetTypeHeader = if ($isSkillTarget) { "скилла" } else { "проекта" }

if (-not (Test-Path -LiteralPath $recFile)) {
    $header = "# Рекомендации по улучшению $targetTypeHeader ($targetName)`n`n> Данный файл содержит входящие межпроектные рекомендации (Advisory Mode / Rule 11).`n"
    [System.IO.File]::WriteAllText($recFile, $header, [System.Text.Encoding]::UTF8)
} else {
    $existing = [System.IO.File]::ReadAllText($recFile, [System.Text.Encoding]::UTF8)
    if ($existing -match '^\s*\*Все входящие рекомендации успешно внедрены') {
        $header = "# Рекомендации по улучшению $targetTypeHeader ($targetName)`n`n> Данный файл содержит входящие межпроектные рекомендации (Advisory Mode / Rule 11).`n"
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
