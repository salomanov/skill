<#
.SYNOPSIS
    Project Guardian v2.2 - Ручная проверка счетчика шагов активной сессии.
.DESCRIPTION
    Показывает, сколько шагов накопила сессия и не пора ли передать контекст
    через prepare-handoff.ps1. Exit 1 - порог перегрузки превышен.

    Если сессию определить не удалось, скрипт честно сообщает об этом и выходит с кодом 0:
    молчание счетчика лучше ложной тревоги "смените диалог" на первом ходу.
.EXAMPLE
    guardian.ps1 steps
.EXAMPLE
    .\session-steps.ps1 -ConversationId 9d5fd6bc-120e-4cce-aa89-488e098cb09f
#>

param(
    [string]$ConversationId = "",
    [int]$Threshold = 500,
    [string]$ProjectPath = (Get-Location).Path,
    [string]$TranscriptPath = ""
)

$ErrorActionPreference = "Stop"
$env:PYTHONIOENCODING = "utf-8"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$lib = Join-Path $PSScriptRoot 'session-guard.ps1'
if (-not (Test-Path -LiteralPath $lib -PathType Leaf)) {
    Write-Host "[steps] Библиотека session-guard.ps1 не найдена рядом с $PSScriptRoot" -ForegroundColor Red
    exit 1
}
. $lib

$steps = Get-ActiveSessionStepCount -TargetConversationId $ConversationId -Threshold $Threshold -ProjectPath $ProjectPath -TranscriptPath $TranscriptPath -NoWarn

if ($steps -le 0) {
    Write-Host "[steps] Сессия не определена: укажите -ConversationId, -TranscriptPath или переменную ANTIGRAVITY_CONVERSATION_ID." -ForegroundColor DarkYellow
    Write-Host "[steps] Ложных тревог не будет, но и контроля перегрузки тоже." -ForegroundColor DarkYellow
    exit 0
}

$userTurns = 0
$plannerSteps = 0
if ($transcript -and (Test-Path -LiteralPath $transcript -PathType Leaf)) {
    try {
        $r = [System.IO.StreamReader]::new($transcript, [System.Text.Encoding]::UTF8)
        while ($null -ne ($ln = $r.ReadLine())) {
            if ($ln -match '"type"\s*:\s*"USER_INPUT"' -or $ln -match '"source"\s*:\s*"USER_EXPLICIT"') { $userTurns++ }
            if ($ln -match '"type"\s*:\s*"PLANNER_RESPONSE"') { $plannerSteps++ }
        }
        $r.Dispose()
    } catch {}
}
if ($userTurns -gt 0 -or $plannerSteps -gt 0) {
    Write-Host "[steps] Сессия: $resolvedId" -ForegroundColor Cyan
    Write-Host "[steps] Событий траектории: $steps (ходов пользователя: $userTurns, ответов модели: $plannerSteps) [порог: $Threshold]" -ForegroundColor Cyan
} else {
    Write-Host "[steps] Шагов в сессии: $steps (порог перегрузки >= $Threshold)" -ForegroundColor Cyan
}
if ($steps -ge $Threshold) {
    Write-Host "[steps] ПОРОГ ПРЕВЫШЕН: запустите prepare-handoff.ps1 и продолжите в новом диалоге." -ForegroundColor Red
    exit 1
}

exit 0
