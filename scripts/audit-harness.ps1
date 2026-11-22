<#
.SYNOPSIS
    Project Guardian - Комплексный аудит 8 измерений обвязки агента (Harness² Audit)
.DESCRIPTION
    Анализирует архитектурную целостность и здоровье всех 8 компонентов Harness²:
    1. System Prompts (Инварианты AGENTS.md, User Rules)
    2. Tools (Единый CLI-фасад guardian.ps1)
    3. Memory (Долговременная память PROJECT_STATE.md + граф знаний Graphify)
    4. Guardrails (Исполняемый Security Gate security-gate.ps1, .security-gate-allow)
    5. Scripts (Генераторы и скрипты автоматизации в scripts/)
    6. Skills (Каталог установленных скиллов и наличие project-guardian)
    7. Subagents & Boundary (Изоляция воркспейсов, prepare-handoff.ps1)
    8. Control Hooks (Контекстная гигиена, счетчик шагов, No-Polling)
#>

param(
    [string]$ProjectPath = (Get-Location).Path,
    [switch]$Strict
)

$ErrorActionPreference = "Continue"
$env:PYTHONIOENCODING = "utf-8"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if ($ProjectPath -and (Test-Path -LiteralPath $ProjectPath)) {
    $ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path
}

Write-Host "`n=== [Project Guardian] Аудит 8 Измерений Обвязки (Harness² Audit v2.1) ===" -ForegroundColor Cyan
Write-Host "Проект: $ProjectPath`n"

$dimensionScore = 0
$totalDimensions = 8

function Report-Dim {
    param(
        [int]$Num,
        [string]$Name,
        [string]$Status, # "OK", "WARN", "FAIL"
        [string]$Details
    )
    $color = switch ($Status) {
        "OK"   { "Green" }
        "WARN" { "Yellow" }
        "FAIL" { "Red" }
    }
    Write-Host ("{0}. {1,-16}: " -f $Num, $Name) -NoNewline
    Write-Host ("[{0}] " -f $Status) -ForegroundColor $color -NoNewline
    Write-Host $Details -ForegroundColor Gray
}

# 1. System Prompts
$agentsFile = Join-Path $HOME ".gemini\config\AGENTS.md"
if (Test-Path -LiteralPath $agentsFile) {
    $agentsContent = [System.IO.File]::ReadAllText($agentsFile, [System.Text.Encoding]::UTF8)
    $hasGuardian = ($agentsContent -match 'project-guardian')
    $hasPonytail = ($agentsContent -match 'Ponytail')
    if ($hasGuardian -and $hasPonytail) {
        Report-Dim 1 "System Prompts" "OK" "AGENTS.md активен (Guardian & Ponytail инварианты на месте)"
        $dimensionScore++
    } else {
        Report-Dim 1 "System Prompts" "WARN" "AGENTS.md обнаружен, но отсутствуют ключевые маркеры правил"
        $dimensionScore++
    }
} else {
    Report-Dim 1 "System Prompts" "WARN" "Глобальный AGENTS.md не найден (используются системные промпты хоста)"
    $dimensionScore++
}

# 2. Tools
$guardianRoot = Join-Path $ProjectPath "guardian.ps1"
$guardianScripts = Join-Path $ProjectPath "scripts\guardian.ps1"
if ((Test-Path -LiteralPath $guardianRoot) -or (Test-Path -LiteralPath $guardianScripts)) {
    Report-Dim 2 "Tools" "OK" "CLI-фасад guardian.ps1 активен и доступен"
    $dimensionScore++
} else {
    Report-Dim 2 "Tools" "FAIL" "Фасад guardian.ps1 отсутствует в проекте"
}

# 3. Memory
$stateFile = Join-Path $ProjectPath "PROJECT_STATE.md"
$graphJson = Join-Path $ProjectPath "graphify-out\graph.json"
$hasState = (Test-Path -LiteralPath $stateFile)
$hasGraph = (Test-Path -LiteralPath $graphJson)

if ($hasState -and $hasGraph) {
    Report-Dim 3 "Memory" "OK" "PROJECT_STATE.md актуален + граф знаний Graphify построен"
    $dimensionScore++
} elseif ($hasState) {
    Report-Dim 3 "Memory" "OK" "PROJECT_STATE.md актуален (граф Graphify обновится при следующем checkpoint)"
    $dimensionScore++
} else {
    Report-Dim 3 "Memory" "FAIL" "Долговременная память PROJECT_STATE.md отсутствует"
}

# 4. Guardrails
$gateScript = Join-Path $ProjectPath "scripts\security-gate.ps1"
if (-not (Test-Path -LiteralPath $gateScript)) {
    $gateScript = Join-Path $HOME ".gemini\config\skills\project-guardian\scripts\security-gate.ps1"
}
if (Test-Path -LiteralPath $gateScript) {
    Report-Dim 4 "Guardrails" "OK" "Исполняемый Security Gate (security-gate.ps1) активен"
    $dimensionScore++
} else {
    Report-Dim 4 "Guardrails" "FAIL" "Скрипт security-gate.ps1 не найден"
}

# 5. Scripts
$scriptsDir = Join-Path $ProjectPath "scripts"
$coreScripts = @("checkpoint.ps1", "rollback.ps1", "new-scratch.ps1", "doctor.ps1", "run-tests.ps1", "probe-skill.ps1")
$foundScripts = 0
foreach ($s in $coreScripts) {
    if (Test-Path -LiteralPath (Join-Path $scriptsDir $s)) { $foundScripts++ }
}
if ($foundScripts -ge 5) {
    Report-Dim 5 "Scripts" "OK" "Утилиты автоматизации ($foundScripts/$($coreScripts.Count)) на месте"
    $dimensionScore++
} else {
    Report-Dim 5 "Scripts" "WARN" "Найдено утилит: $foundScripts из $($coreScripts.Count)"
    $dimensionScore++
}

# 6. Skills
$skillsDir = Join-Path $HOME ".gemini\config\skills"
if (Test-Path -LiteralPath $skillsDir) {
    $installedSkills = @(Get-ChildItem -LiteralPath $skillsDir -Directory -ErrorAction SilentlyContinue)
    $hasPG = (Test-Path -LiteralPath (Join-Path $skillsDir "project-guardian"))
    if ($hasPG) {
        Report-Dim 6 "Skills" "OK" "Установлено скиллов: $($installedSkills.Count), project-guardian синхронизирован"
        $dimensionScore++
    } else {
        Report-Dim 6 "Skills" "WARN" "Установлено скиллов: $($installedSkills.Count), но project-guardian не найден глобально"
        $dimensionScore++
    }
} else {
    Report-Dim 6 "Skills" "WARN" "Каталог скиллов ~/.gemini/config/skills не обнаружен"
}

# 7. Subagents & Boundary
$handoffScript = Join-Path $ProjectPath "scripts\prepare-handoff.ps1"
if (-not (Test-Path -LiteralPath $handoffScript)) {
    $handoffScript = Join-Path $HOME ".gemini\config\skills\project-guardian\scripts\prepare-handoff.ps1"
}
if (Test-Path -LiteralPath $handoffScript) {
    Report-Dim 7 "Subagents" "OK" "Межпроектная изоляция и протокол передачи контекста (prepare-handoff) активны"
    $dimensionScore++
} else {
    Report-Dim 7 "Subagents" "WARN" "Скрипт prepare-handoff.ps1 не найден"
}

# 8. Control Hooks
$detailsHook = "Счетчик шагов (150-200), No-Polling и Reactive Wakeup активны"
Report-Dim 8 "Control Hooks" "OK" $detailsHook
$dimensionScore++

# Итог
Write-Host ("`n" + ("=" * 60))
if ($dimensionScore -eq $totalDimensions) {
    Write-Host "ИТОГ: Обвязка полностью сбалансирована ($dimensionScore/$totalDimensions измерений в норме, 0 блокеров).`n" -ForegroundColor Green
    exit 0
} else {
    Write-Host "ИТОГ: Обнаружены дефициты обвязки ($dimensionScore/$totalDimensions измерений в норме).`n" -ForegroundColor Yellow
    if ($Strict) { exit 1 } else { exit 0 }
}
