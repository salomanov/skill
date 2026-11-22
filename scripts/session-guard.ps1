<#
.SYNOPSIS
    Project Guardian v2.2 - Механический счетчик шагов сессии (единая точка правды).
.DESCRIPTION
    Считает ШАГИ сессии (поле step_index в transcript.jsonl Antigravity), а не строки лога:
    одна реплика агента порождает десятки строк JSONL, поэтому подсчет строк давал
    ложную тревогу "перегрузки контекста" на 5-10 ходу работы.

    Резолв сессии (по убыванию надежности):
      1. Явный -TargetConversationId.
      2. Переменные окружения ANTIGRAVITY_CONVERSATION_ID / GEMINI_CONVERSATION_ID / CONVERSATION_ID.
      3. Эвристика: свежий (<= 10 минут) лог, в котором упоминается ПУТЬ ТЕКУЩЕГО ПРОЕКТА.
         Угадывать "самый свежий лог" без этой проверки запрещено: в v2.1.0 счетчик
         подхватывал чужую сессию (другой проект) и требовал сменить диалог на первом ходу.

    Если сессию определить не удалось, функция МОЛЧИТ и возвращает 0:
    лучше не сработать, чем кричать не по адресу.

    Подключается через dot-source из checkpoint.ps1 и security-gate.ps1.
#>

function Get-ActiveSessionStepCount {
    [CmdletBinding()]
    param(
        [string]$TargetConversationId = "",
        [int]$Threshold = 180,
        [string]$ProjectPath = (Get-Location).Path,
        [string]$TranscriptPath = "",
        [switch]$NoWarn
    )

    $brainRoot = Join-Path $HOME '.gemini/antigravity/brain'
    $transcriptName = Join-Path '.system_generated' (Join-Path 'logs' 'transcript.jsonl')

    function Resolve-TranscriptPath([string]$id) {
        if ([string]::IsNullOrWhiteSpace($id)) { return $null }
        $p = Join-Path (Join-Path $brainRoot $id) $transcriptName
        if (Test-Path -LiteralPath $p -PathType Leaf) { return $p }
        return $null
    }

    # 0. Явный путь к логу (диагностика и автотесты)
    $transcript = $null
    if (-not [string]::IsNullOrWhiteSpace($TranscriptPath)) {
        if (Test-Path -LiteralPath $TranscriptPath -PathType Leaf) {
            $transcript = (Resolve-Path -LiteralPath $TranscriptPath).Path
            $resolvedId = 'test-transcript'
        } else {
            return 0
        }
    }

    # 1-2. Явный ID или переменные окружения
    if (-not $transcript) {
        $resolvedId = $TargetConversationId
        if ([string]::IsNullOrWhiteSpace($resolvedId)) {
            foreach ($varName in @('ANTIGRAVITY_CONVERSATION_ID', 'GEMINI_CONVERSATION_ID', 'CONVERSATION_ID')) {
                $val = [Environment]::GetEnvironmentVariable($varName)
                if ($val) { $resolvedId = $val.Trim(); break }
            }
        }

        $transcript = Resolve-TranscriptPath $resolvedId
    }

    # 3. Эвристика: только свежий лог, где встречается путь проекта (в т.ч. JSON-экранированный)
    if (-not $transcript) {
        if (-not (Test-Path -LiteralPath $brainRoot -PathType Container)) { return 0 }
        $cutoff = (Get-Date).AddMinutes(-10)
        $needle = ([string]$ProjectPath).TrimEnd('\', '/')
        if ([string]::IsNullOrWhiteSpace($needle)) { return 0 }

        $variants = @(
            $needle,
            $needle.Replace('\', '\\'),
            $needle.Replace('\', '\\\\'),
            $needle.Replace('\', '/'),
            $needle.Replace('\', '\\').ToLowerInvariant()
        ) | Where-Object { $_ } | Select-Object -Unique

        $best = $null
        foreach ($dir in (Get-ChildItem -LiteralPath $brainRoot -Directory -ErrorAction SilentlyContinue)) {
            $t = Join-Path $dir.FullName $transcriptName
            if (-not (Test-Path -LiteralPath $t -PathType Leaf)) { continue }
            $fi = Get-Item -LiteralPath $t
            if ($fi.LastWriteTime -lt $cutoff) { continue }
            $tail = ''
            try {
                $tail = ((Get-Content -LiteralPath $t -Tail 200 -Encoding UTF8 -ErrorAction SilentlyContinue) -join "`n")
            } catch { $tail = '' }
            if (-not $tail) { continue }
            $hit = $false
            foreach ($v in $variants) {
                if ($tail.IndexOf($v, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { $hit = $true; break }
            }
            if (-not $hit) { continue }
            if (-not $best -or $fi.LastWriteTime -gt $best.LastWriteTime) {
                $best = [pscustomobject]@{ Id = $dir.Name; Path = $t; LastWriteTime = $fi.LastWriteTime }
            }
        }

        if (-not $best) { return 0 }
        $resolvedId = $best.Id
        $transcript = $best.Path
    }

    # Подсчет шагов: максимум step_index + 1 (fallback - число строк, если поля нет)
    $maxStep = -1
    $lineCount = 0
    $reader = $null
    try {
        $reader = [System.IO.StreamReader]::new($transcript, [System.Text.Encoding]::UTF8)
        while ($null -ne ($line = $reader.ReadLine())) {
            $lineCount++
            $m = [regex]::Match($line, '"step_index"\s*:\s*(\d+)')
            if ($m.Success) {
                $v = [int]$m.Groups[1].Value
                if ($v -gt $maxStep) { $maxStep = $v }
            }
        }
    } catch { return 0 }
    finally { if ($null -ne $reader) { $reader.Dispose() } }

    $steps = if ($maxStep -ge 0) { $maxStep + 1 } else { $lineCount }

    if (-not $NoWarn -and $steps -ge $Threshold) {
        $w = 78
        $border = '#' * $w
        $row = '#   {0,-72} #'

        Write-Host ''
        Write-Host $border -ForegroundColor Red
        Write-Host ($row -f '') -ForegroundColor Red
        Write-Host ($row -f '!!! MECHANICAL STEP COUNTER :: CONTEXT HYGIENE GUARD !!!') -ForegroundColor Red
        Write-Host ($row -f '') -ForegroundColor Red
        Write-Host ($row -f "Сессия: $resolvedId") -ForegroundColor Red
        Write-Host ($row -f "Шагов в сессии: $steps (порог перегрузки >= $Threshold)") -ForegroundColor Red
        Write-Host ($row -f '') -ForegroundColor Red
        Write-Host ($row -f '>>> ВНИМАНИЕ: СРОЧНО ЗАПУСТИТЬ prepare-handoff.ps1 И СМЕНИТЬ ДИАЛОГ! <<<') -ForegroundColor Red
        Write-Host ($row -f 'Во избежание когнитивной деградации агента продолжите работу в новом чате.') -ForegroundColor Red
        Write-Host ($row -f '') -ForegroundColor Red
        Write-Host $border -ForegroundColor Red
        Write-Host ''
    }

    return $steps
}
