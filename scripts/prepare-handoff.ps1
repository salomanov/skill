param(
    [string]$ProjectPath = (Get-Location).Path,
    [string]$SubProject = "",
    [string]$DialogTitle = "",
    [string]$ConversationId = "",
    [switch]$NoAutoCreate,
    [Parameter(Position=0)]
    [string[]]$NextGoal = @(""),
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$ExtraArgs
)

$ErrorActionPreference = "Continue"
$env:PYTHONIOENCODING = "utf-8"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if ($ExtraArgs) {
    $all = @($NextGoal) + @($ExtraArgs)
    $NextGoal = ($all -join " ").Trim()
} elseif ($NextGoal -is [array]) {
    $NextGoal = ($NextGoal -join " ").Trim()
}

# 0. Нормализация пути и поддержка подпроектов
if ($ProjectPath -and (Test-Path -LiteralPath $ProjectPath)) {
    $ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path
}

if ($SubProject) {
    $cand = Join-Path $ProjectPath $SubProject
    if (Test-Path -LiteralPath $cand) {
        $ProjectPath = (Resolve-Path -LiteralPath $cand).Path
    }
}

Write-Host "`n=== [Project Guardian] Подготовка передачи контекста в новый диалог ===" -ForegroundColor Cyan
Write-Host "Проект: $ProjectPath"

$agentsDir = Join-Path $ProjectPath ".agents"
if (-not (Test-Path -LiteralPath $agentsDir)) {
    New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
}

$handoffFile = Join-Path $agentsDir "HANDOFF.md"
$projectName = Split-Path $ProjectPath -Leaf

# Считывание ранее сохраненного названия диалога из существующего HANDOFF.md
$previousHandoffTitle = ""
if (Test-Path -LiteralPath $handoffFile) {
    try {
        $oldHandoffLines = Get-Content -LiteralPath $handoffFile -Encoding UTF8 -ErrorAction SilentlyContinue
        foreach ($hl in $oldHandoffLines) {
            if ($hl -match '^- \*\*Название диалога\*\*:\s*(.+)$') {
                $previousHandoffTitle = $matches[1].Trim()
                break
            }
        }
    } catch {}
}

# Резолв ConversationId из окружения, если не передан
if (-not $ConversationId) {
    foreach ($varName in @('ANTIGRAVITY_CONVERSATION_ID', 'GEMINI_CONVERSATION_ID', 'CONVERSATION_ID')) {
        $val = [Environment]::GetEnvironmentVariable($varName)
        if ($val) {
            $ConversationId = $val.Trim()
            break
        }
    }
}

# Получение названия диалога из conversation_summaries.db
if (-not $DialogTitle) {
    $titleHelper = Join-Path $PSScriptRoot "get_dialog_title.py"
    $pyCmd = Get-Command python -ErrorAction SilentlyContinue
    if ($pyCmd -and (Test-Path -LiteralPath $titleHelper)) {
        try {
            $dbTitle = (& $pyCmd.Source $titleHelper --mode get --cid $ConversationId --path $ProjectPath 2>$null)
            if ($dbTitle) {
                $DialogTitle = ($dbTitle | Select-Object -First 1).Trim()
            }
        } catch {}
    }
}

# Получение данных Git
$branch = "main"
$lastCommit = "нет коммитов"
$changedFiles = @()

try {
    $branch = (& git -C $ProjectPath rev-parse --abbrev-ref HEAD 2>$null).Trim()
    $lastCommit = (& git -C $ProjectPath log -1 --pretty=format:"%s (%h)" 2>$null)
    $diffFiles = (& git -C $ProjectPath diff-tree --no-commit-id --name-only -r HEAD 2>$null)
    if ($diffFiles) { $changedFiles = @($diffFiles) }
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

if (Test-Path -LiteralPath $stateFile) {
    $stateLines = Get-Content -LiteralPath $stateFile -Encoding UTF8
    $inStack = $false
    $inChanges = $false
    $inNext = $false

    foreach ($line in $stateLines) {
        if ($line -match "^## (?:\d+\.\s*)?Стек Технологий") { 
            $inStack = $true; $inChanges = $false; $inNext = $false; continue 
        }
        if ($line -match "^## (?:\d+\.\s*)?История Изменений") { 
            $inChanges = $true; $inStack = $false; $inNext = $false; continue 
        }
        if ($line -match "^## (?:\d+\.\s*)?Следующие Шаги") { 
            $inNext = $true; $inStack = $false; $inChanges = $false; continue 
        }
        if ($line -match "^##\s+") {
            $inStack = $false
            $inChanges = $false
            $inNext = $false
        }

        if ($inStack -and $line -match "^- \*\*") {
            $stackItems += $line.Replace("- **", "").Replace("**", "").Trim()
        }
        if ($inChanges -and $recentChanges -eq "Продолжение разработки") {
            if ($line -match "^- .*?\*\*\s*\[[^\]]+\](?:\s*\(метка:[^)]+\))?:\s*(.+)$") {
                $candChange = $matches[1].Trim()
                if ($candChange -notmatch "^Pre-v") {
                    $recentChanges = $candChange
                }
            } elseif ($line -match "^\s*-\s*\*\*Что сделано\*\*:\s*(.+)$") {
                $recentChanges = $matches[1].Trim()
            }
        }
        if ($inNext -and $line -match "^\d+\.\s+(.*)") {
            $pendingTasks += $matches[1].Trim()
        }
    }

    if ($stackItems.Count -gt 0) {
        $stackInfo = $stackItems -join " | "
    }
}

$taskGoal = if ($NextGoal) { $NextGoal } elseif ($pendingTasks.Count -gt 0) { $pendingTasks[0] } else { "Продолжить реализацию следующего этапа" }

if (-not $DialogTitle) {
    if ($previousHandoffTitle) {
        $DialogTitle = $previousHandoffTitle
    } else {
        $DialogTitle = "$projectName — $taskGoal"
    }
}

# Проверка открытых рекомендаций в AGENT_RECOMMENDATIONS.md
$recFile = Join-Path $ProjectPath "AGENT_RECOMMENDATIONS.md"
$openRecCount = 0
if (Test-Path -LiteralPath $recFile) {
    try {
        $recText = [System.IO.File]::ReadAllText($recFile, [System.Text.Encoding]::UTF8)
        $openRecCount = ([regex]::Matches($recText, '\[ \]\s*ТРЕБУЕТ ВНЕДРЕНИЯ')).Count
    } catch {}
}

$recLine = ""
if ($openRecCount -gt 0) {
    $recLine = "`nВходящие рекомендации: $openRecCount открытых задач в AGENT_RECOMMENDATIONS.md"
}

# Генерация готового промпта для нового диалога (первая строка сохраняет название диалога!)
$handoffPrompt = @"
Тема диалога: $DialogTitle
Привет! Мы продолжаем работу над проектом '$projectName' в папке: $ProjectPath
Стек: $stackInfo | Ветка Git: $branch | Последний коммит: $lastCommit
Контекст изменений: $recentChanges
Задача на текущую сессию: $taskGoal$recLine

Пожалуйста, первым делом прочитай PROJECT_STATE.md для загрузки полной памяти проекта и подтверди готовность к задаче.
"@

# Сохранение в .agents/HANDOFF.md (используем $fence чтобы избежать превращения `t в табуляцию)
$fence = '```'
$handoffDoc = @"
# Контекст передачи проекта в новый диалог (Handoff)

- **Название диалога**: $DialogTitle
- **Проект**: $projectName ($ProjectPath)
- **Дата формирования**: $((Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))
- **Стек**: $stackInfo
- **Ветка Git**: $branch
- **Последний коммит**: $lastCommit
- **Последние изменения**: $recentChanges

---

## Готовый промпт для вставки в новый чат:
${fence}text
$handoffPrompt
${fence}

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

# Попытка автоматического создания диалога через Antigravity ConversationService
$createdConvId = $null
$createError = $null

if (-not $NoAutoCreate -and $env:ANTIGRAVITY_LS_ADDRESS -and $env:ANTIGRAVITY_CSRF_TOKEN) {
    try {
        $headers = @{
            "Content-Type" = "application/json"
            "Connect-Protocol-Version" = "1"
            "x-antigravity-csrf-token" = $env:ANTIGRAVITY_CSRF_TOKEN
        }
        $payload = @{
            title = $DialogTitle
            prompt = @(@{ text = $handoffPrompt })
        }
        if ($env:ANTIGRAVITY_PROJECT_ID) {
            $payload["projectId"] = $env:ANTIGRAVITY_PROJECT_ID
        }
        $body = ($payload | ConvertTo-Json -Depth 5 -Compress)
        $url = "http://$($env:ANTIGRAVITY_LS_ADDRESS)/product.v1.ConversationService/CreateConversation"
        $res = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 15 -ErrorAction Stop
        if ($res -and $res.conversation -and $res.conversation.id) {
            $createdConvId = $res.conversation.id
            
            # Дописываем ссылку на созданный диалог в HANDOFF.md
            $handoffDocWithConv = $handoffDoc.Replace(
                "- **Название диалога**: $DialogTitle",
                "- **Название диалога**: $DialogTitle`n- **Созданный диалог**: [$DialogTitle](conversation://$createdConvId)"
            )
            [System.IO.File]::WriteAllText($handoffFile, $handoffDocWithConv, [System.Text.Encoding]::UTF8)
        }
    } catch {
        $createError = $_.Exception.Message
    }
}

Write-Host "[OK] Файл контекста сохранен: $handoffFile" -ForegroundColor Green
Write-Host "[OK] Сохранено название диалога: $DialogTitle" -ForegroundColor Magenta

if ($createdConvId) {
    Write-Host "`n[OK] НОВЫЙ ДИАЛОГ АВТОМАТИЧЕСКИ СОЗДАН В ANTIGRAVITY!" -ForegroundColor Green
    Write-Host "ID диалога: $createdConvId" -ForegroundColor Cyan
    Write-Host ("`n" + ("=" * 70)) -ForegroundColor Cyan
    Write-Host " НАЖМИТЕ ДЛЯ МГНОВЕННОГО ПЕРЕХОДА В НОВЫЙ ДИАЛОГ:" -ForegroundColor Yellow
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host "👉 [$DialogTitle](conversation://$createdConvId)" -ForegroundColor Green
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host ""
} else {
    if ($createError) {
        Write-Host "[WARN] Авто-создание диалога через API недоступно: $createError" -ForegroundColor DarkYellow
    }
    Write-Host ("`n" + ("=" * 70)) -ForegroundColor Cyan
    Write-Host "СКОПИРУЙТЕ ЭТОТ ПРОМПТ В НОВЫЙ ДИАЛОГ ДЛЯ МГНОВЕННОГО ВХОДА В КОНТЕКСТ:" -ForegroundColor Yellow
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host $handoffPrompt -ForegroundColor White
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host ""
}
