<#
.SYNOPSIS
    Project Guardian v2.0 - Единый интерфейс (фасад) для всех утилит проекта.
.DESCRIPTION
    Объединяет управление контрольными точками, диагностику (doctor), проверку безопасности
    (security gate), автотесты, откат, фиксацию сбоев, передачу контекста (handoff),
    scratch-скрипты, ротацию бэкапов и установку скиллов в единую консольную команду.
#>

$ErrorActionPreference = "Stop"
$env:PYTHONIOENCODING = "utf-8"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

function Resolve-GuardianScriptsPath {
    $candidates = @(
        (Join-Path $PSScriptRoot 'scripts'),
        $PSScriptRoot
    )

    try {
        $gitRoot = git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and $gitRoot) {
            $candidates += (Join-Path $gitRoot.Trim() 'scripts')
        }
    } catch { }
    $global:LASTEXITCODE = 0

    $globalSkill = Join-Path $HOME '.gemini\config\skills\project-guardian\scripts'
    if (Test-Path -LiteralPath $globalSkill) {
        $candidates += $globalSkill
    }

    $cwdScripts = Join-Path (Get-Location).Path 'scripts'
    if (Test-Path -LiteralPath $cwdScripts) {
        $candidates += $cwdScripts
    }

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath (Join-Path $candidate 'checkpoint.ps1'))) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw "Guardian: каталог scripts/ не найден относительно '$PSScriptRoot' или git root."
}

$CommandMap = @{
    'checkpoint'   = 'checkpoint.ps1'
    'cp'           = 'checkpoint.ps1'
    'doctor'       = 'doctor.ps1'
    'doc'          = 'doctor.ps1'
    'gate'         = 'security-gate.ps1'
    'security'     = 'security-gate.ps1'
    'sec'          = 'security-gate.ps1'
    'test'         = 'run-tests.ps1'
    'tests'        = 'run-tests.ps1'
    'rollback'     = 'rollback.ps1'
    'rb'           = 'rollback.ps1'
    'failure'      = 'record-failure.ps1'
    'record'       = 'record-failure.ps1'
    'fail'         = 'record-failure.ps1'
    'handoff'      = 'prepare-handoff.ps1'
    'scratch'      = 'new-scratch.ps1'
    'clean'        = 'clean-backups.ps1'
    'env'          = 'gen-env.ps1'
    'install'      = 'install-skill.ps1'
    'check-skills' = 'check-new-skills.ps1'
    'recommend'    = 'add-recommendation.ps1'
    'email'        = 'send-email.ps1'
}

function Show-GuardianHelp {
    Write-Host "`n🛡️ Project Guardian v2.0 CLI (Universal Facade)" -ForegroundColor Cyan
    Write-Host "Использование: guardian.ps1 <команда> [параметры...]" -ForegroundColor White
    Write-Host "`nДоступные команды:" -ForegroundColor Yellow
    
    $commands = @(
        [PSCustomObject]@{ Команда = 'checkpoint (cp)'; Описание = 'Чекпоинт кода, релизный билд (-Release), прошивка (-Firmware), авто-коммит (-Push)' },
        [PSCustomObject]@{ Команда = 'doctor (doc)'; Описание = 'Экспресс-диагностика окружения, Git, памяти и запуск Security Gate' },
        [PSCustomObject]@{ Команда = 'gate (security, sec)'; Описание = 'Исполняемый Security Gate: секреты, синтаксис AST, BOM, инварианты' },
        [PSCustomObject]@{ Команда = 'test (tests)'; Описание = 'Автопоиск и запуск тестовых фреймворков (pytest, npm test, unittest)' },
        [PSCustomObject]@{ Команда = 'rollback (rb)'; Описание = 'Откат к контрольной точке или просмотр списка (-List)' },
        [PSCustomObject]@{ Команда = 'failure (record, fail)'; Описание = 'Фиксация сбоя/инцидента в docs/ERRORS_AND_FAILURES.md' },
        [PSCustomObject]@{ Команда = 'handoff'; Описание = 'Подготовка контекста для передачи в новый диалог (.agents/HANDOFF.md)' },
        [PSCustomObject]@{ Команда = 'scratch'; Описание = 'Генерация scratch-скрипта (Python/Bash) с UTF-8 и учетными данными' },
        [PSCustomObject]@{ Команда = 'clean'; Описание = 'Безопасная ротация старых бэкапов с защитой релизов (-DryRun)' },
        [PSCustomObject]@{ Команда = 'env'; Описание = 'Сканирование переменных окружения и сборка .env.example' },
        [PSCustomObject]@{ Команда = 'install'; Описание = 'Автономная установка/обновление скилла из каталога Agentic Awesome Skills' },
        [PSCustomObject]@{ Команда = 'check-skills'; Описание = 'Мониторинг обновлений и свежих скиллов в апстриме' },
        [PSCustomObject]@{ Команда = 'recommend'; Описание = 'Фиксация рекомендаций во внешнем проекте (AGENT_RECOMMENDATIONS.md)' },
        [PSCustomObject]@{ Команда = 'email'; Описание = 'Универсальная отправка файлов или отчётов на email' }
    )

    foreach ($c in $commands) {
        Write-Host ("  {0,-24} {1}" -f $c.Команда, $c.Описание)
    }

    Write-Host "`nПримеры:" -ForegroundColor Yellow
    Write-Host "  .\guardian.ps1 checkpoint `"Фикс авторизации`"" -ForegroundColor Gray
    Write-Host "  .\guardian.ps1 doctor" -ForegroundColor Gray
    Write-Host "  .\guardian.ps1 gate" -ForegroundColor Gray
    Write-Host "  .\guardian.ps1 test" -ForegroundColor Gray
    Write-Host "  .\guardian.ps1 rollback -List" -ForegroundColor Gray
    Write-Host "  .\guardian.ps1 failure -Title `"OOM`" -Symptom `"Краш`" -RootCause `"Лимит памяти`" -Solution `"Swap`"" -ForegroundColor Gray
    Write-Host "  .\guardian.ps1 handoff -NextGoal `"Продолжить рефакторинг`"`
" -ForegroundColor Gray
}

if ($args.Count -eq 0 -or $args[0] -in @('-h', '--help', 'help', '/?', '-?', 'info')) {
    Show-GuardianHelp
    exit 0
}

$Cmd = $args[0].ToLowerInvariant()
[object[]]$RestArgs = if ($args.Count -gt 1) { [object[]]$args[1..($args.Count - 1)] } else { @() }

if (-not $CommandMap.ContainsKey($Cmd)) {
    Write-Host "`n[ERROR] Неизвестная команда Guardian: '$Cmd'" -ForegroundColor Red
    Write-Host "Используйте .\guardian.ps1 --help для просмотра доступных команд.`
" -ForegroundColor Yellow
    exit 1
}

$ScriptsPath = Resolve-GuardianScriptsPath
$TargetScript = Join-Path $ScriptsPath $CommandMap[$Cmd]

if (-not (Test-Path -LiteralPath $TargetScript)) {
    Write-Host "`n[ERROR] Целевой скрипт не найден: $TargetScript" -ForegroundColor Red
    exit 1
}

$exitCode = 0
try {
    if ($RestArgs -and $RestArgs.Count -gt 0) {
        & $TargetScript @RestArgs
    } else {
        & $TargetScript
    }
    if ($LASTEXITCODE) {
        $exitCode = $LASTEXITCODE
    }
} catch {
    Write-Error $_
    $exitCode = 1
}

exit $exitCode
