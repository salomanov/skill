param(
    [Parameter(Position=0)]
    [string[]]$Message = @("Automatic checkpoint"),
    [switch]$Push = $false,   # Пуш в remote — только по явному -Push
    [switch]$NoPush = $false, # Совместимость со старыми вызовами
    [string]$Category = "Auto", # "Auto", "Code", "Web", "Desktop", "Firmware"
    [switch]$Firmware = $false,  # Обратная совместимость
    [switch]$Release = $false,   # Флаг сохранения релизного билда (exe, web dist, бинарник)
    [switch]$NoGraphify = $false,# Пропустить автоматическое обновление графа graphify
    [switch]$Verify = $false,    # Запустить авто-тесты перед чекпоинтом
    [string]$ProjectPath = (Get-Location).Path,
    [string]$SubProject = "",    # Явное указание подпроекта в составном воркспейсе / монорепозитории
    [switch]$IncludeSubprojects = $false, # При бэкапе корня воркспейса включать вложенные проекты
    [string]$ConversationId = "",         # Явный ID диалога (по умолчанию берется из $env:ANTIGRAVITY_CONVERSATION_ID)
    [string]$FailureTitle = "",           # Опционально: зафиксировать ошибку перед чекпоинтом
    [string]$Symptom = "",
    [string]$RootCause = "",
    [string]$Solution = "",
    [switch]$RecommendToSkill = $false,
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$ExtraArgs
)

$ErrorActionPreference = "Stop"
$env:PYTHONIOENCODING = "utf-8"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Нормализация $Message: поддержка неэкранированных пробелов, вызовов без кавычек и нескольких аргументов
if ($ExtraArgs) {
    $all = @($Message) + @($ExtraArgs)
    $Message = ($all -join " ").Trim()
} elseif ($Message -is [array]) {
    $Message = ($Message -join " ").Trim()
}
if ([string]::IsNullOrWhiteSpace($Message)) {
    $Message = "Automatic checkpoint"
}

# --- Mechanical Step Counter & Context Hygiene Guard (Project Guardian v1.7.10) ---
function Get-ActiveSessionStepCount {
    [CmdletBinding()]
    param(
        [string]$TargetConversationId = "",
        [int]$Threshold = 180
    )

    $resolvedId = $TargetConversationId
    if (-not $resolvedId) {
        foreach ($varName in @('ANTIGRAVITY_CONVERSATION_ID', 'GEMINI_CONVERSATION_ID', 'CONVERSATION_ID')) {
            $val = [Environment]::GetEnvironmentVariable($varName)
            if ($val) {
                $resolvedId = $val.Trim()
                break
            }
        }
    }

    $brainRoot = Join-Path $HOME '.gemini/antigravity/brain'

    if (-not $resolvedId) {
        if (Test-Path -LiteralPath $brainRoot -PathType Container) {
            $cutoff = (Get-Date).AddSeconds(-60)
            $freshSession = Get-ChildItem -LiteralPath $brainRoot -Directory -ErrorAction SilentlyContinue |
                ForEach-Object {
                    $tPath = Join-Path $_.FullName '.system_generated/logs/transcript.jsonl'
                    if (Test-Path -LiteralPath $tPath -PathType Leaf) {
                        $fi = Get-Item -LiteralPath $tPath
                        if ($fi.LastWriteTime -ge $cutoff) {
                            [pscustomobject]@{ Id = $_.Name; LastWriteTime = $fi.LastWriteTime }
                        }
                    }
                } | Sort-Object LastWriteTime -Descending | Select-Object -First 1

            if ($freshSession) {
                $resolvedId = $freshSession.Id
            }
        }
    }

    if (-not $resolvedId) { return 0 }

    $transcript = Join-Path (Join-Path $brainRoot $resolvedId) '.system_generated/logs/transcript.jsonl'
    if (-not (Test-Path -LiteralPath $transcript -PathType Leaf)) { return 0 }

    $stepCount = 0
    $reader = $null
    try {
        $reader = [System.IO.StreamReader]::new($transcript)
        while ($null -ne $reader.ReadLine()) { $stepCount++ }
    }
    catch { return 0 }
    finally { if ($null -ne $reader) { $reader.Dispose() } }

    if ($stepCount -ge $Threshold) {
        $w = 78
        $border = '#' * $w
        $row = '#   {0,-72} #'

        Write-Host ''
        Write-Host $border -ForegroundColor Red
        Write-Host ($row -f '') -ForegroundColor Red
        Write-Host ($row -f '!!! MECHANICAL STEP COUNTER :: CONTEXT HYGIENE GUARD !!!') -ForegroundColor Red
        Write-Host ($row -f '') -ForegroundColor Red
        Write-Host ($row -f "Сессия: $resolvedId") -ForegroundColor Red
        Write-Host ($row -f "Шагов в логе: $stepCount (порог перегрузки >= $Threshold)") -ForegroundColor Red
        Write-Host ($row -f '') -ForegroundColor Red
        Write-Host ($row -f '>>> ВНИМАНИЕ: СРОЧНО ЗАПУСТИТЬ prepare-handoff.ps1 И СМЕНИТЬ ДИАЛОГ! <<<') -ForegroundColor Red
        Write-Host ($row -f 'Во избежание когнитивной деградации агента продолжите работу в новом чате.') -ForegroundColor Red
        Write-Host ($row -f '') -ForegroundColor Red
        Write-Host $border -ForegroundColor Red
        Write-Host ''
    }

    return $stepCount
}

$activeSteps = Get-ActiveSessionStepCount -TargetConversationId $ConversationId

# 0. Нормализация пути и автоопределение подпроекта в составных воркспейсах
if ($ProjectPath -and (Test-Path -LiteralPath $ProjectPath)) {
    $ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path
}

$isCompositeRoot = $false
if ($SubProject) {
    $candidateSub = Join-Path $ProjectPath $SubProject
    if (Test-Path -LiteralPath $candidateSub) {
        $ProjectPath = (Resolve-Path -LiteralPath $candidateSub).Path
        Write-Host "[Project Guardian] 🎯 Выбран подпроект: $ProjectPath" -ForegroundColor Cyan
    } else {
        Write-Warning "Указанный подпроект '$SubProject' не найден в $ProjectPath"
    }
} else {
    $subProjects = @(Get-ChildItem -LiteralPath $ProjectPath -Directory -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -notmatch '^(\.git|\.backups|node_modules|\.venv|venv|scratch|graphify-out)$' -and
        (Test-Path -LiteralPath (Join-Path $_.FullName "PROJECT_STATE.md"))
    })

    if ($subProjects.Count -gt 0) {
        $isCompositeRoot = $true
        $gitSub = $null
        try {
            $prevEAP = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            $gitStatus = & git -C $ProjectPath status --porcelain 2>$null
            $ErrorActionPreference = $prevEAP
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
                    $gitSub = $subHits.Keys | Select-Object -First 1
                }
            }
        } catch {}

        if ($gitSub) {
            $ProjectPath = $gitSub
            $isCompositeRoot = $false
            $spName = Split-Path $ProjectPath -Leaf
            Write-Host "[Project Guardian] 🎯 Автоопределение: активный подпроект '$spName' (по изменениям Git)." -ForegroundColor Cyan
            Write-Host "   Чекпоинт создается изолированно в $ProjectPath\.backups" -ForegroundColor Gray
        } else {
            Write-Host "[Project Guardian] ℹ️ Составной воркспейс с подпроектами: $($subProjects.Name -join ', ')" -ForegroundColor DarkCyan
            Write-Host "   Для изолированного чекпоинта подпроекта передайте: -ProjectPath <путь> или -SubProject <имя>" -ForegroundColor Gray
        }
    }
}

# 0.2. Синхронизация сохранённого названия диалога из .agents/HANDOFF.md в conversation_summaries.db
$handoffFile = Join-Path $ProjectPath ".agents\HANDOFF.md"
if (Test-Path -LiteralPath $handoffFile) {
    try {
        $hLines = Get-Content -LiteralPath $handoffFile -Encoding UTF8 -ErrorAction SilentlyContinue
        $savedTitle = ""
        foreach ($hl in $hLines) {
            if ($hl -match '^- \*\*Название диалога\*\*:\s*(.+)$') {
                $savedTitle = $matches[1].Trim()
                break
            }
        }
        if ($savedTitle) {
            $titleHelper = Join-Path $PSScriptRoot "get_dialog_title.py"
            $pyCmdTitle = Get-Command python -ErrorAction SilentlyContinue
            if ($pyCmdTitle -and (Test-Path -LiteralPath $titleHelper)) {
                $prevEAP = $ErrorActionPreference
                $ErrorActionPreference = "Continue"
                $synced = (& $pyCmdTitle.Source $titleHelper --mode set --cid $ConversationId --path $ProjectPath --title $savedTitle 2>$null)
                $ErrorActionPreference = $prevEAP
                if ($synced) {
                    Write-Host "[Project Guardian] 🏷️ Название диалога синхронизировано: $savedTitle" -ForegroundColor Magenta
                }
            }
        }
    } catch {}
}

# 0.5. Встроенная фиксация ошибки (если передан -FailureTitle) и FAIL-GUARD / REC-GUARD
if ($FailureTitle) {
    $recFailScript = Join-Path $PSScriptRoot "record-failure.ps1"
    if (Test-Path -LiteralPath $recFailScript) {
        $rfParams = @{
            Title = $FailureTitle
            ProjectPath = $ProjectPath
            NoCheckpoint = $true
        }
        if ($Symptom) { $rfParams.Symptom = $Symptom }
        if ($RootCause) { $rfParams.RootCause = $RootCause }
        if ($Solution) { $rfParams.Solution = $Solution }
        if ($RecommendToSkill) { $rfParams.RecommendToSkill = $true }
        & $recFailScript @rfParams
    }
} elseif ($Message -notmatch '^failure:' -and $Message -match '(?i)\b(fix|fixed|bug|crash|hang|deadlock|error|regression)\b|исправ|ошибк|сбой|краш|баг|зависан|регресс') {
    $errFile1 = Join-Path $ProjectPath "docs\ERRORS_AND_FAILURES.md"
    $errFile2 = Join-Path $ProjectPath "ERRORS_AND_FAILURES.md"
    $errFileFound = if (Test-Path -LiteralPath $errFile1) { $errFile1 } elseif (Test-Path -LiteralPath $errFile2) { $errFile2 } else { $null }
    $isRecent = $false
    if ($errFileFound) {
        $lastMod = (Get-Item -LiteralPath $errFileFound).LastWriteTime
        if ($lastMod -ge (Get-Date).AddMinutes(-30)) { $isRecent = $true }
    }
    if (-not $isRecent) {
        Write-Host "`n[FAIL-GUARD] ⚠️ Обнаружен багфикс-чекпоинт ('$Message') без свежей записи в docs/ERRORS_AND_FAILURES.md!" -ForegroundColor Yellow
        Write-Host "  Правило Guardian: фиксируйте первопричину сбоя через record-failure.ps1 (или передайте -FailureTitle)." -ForegroundColor DarkYellow
    }
}

# Проверка входящих рекомендаций (REC-GUARD)
$recFileCheck = Join-Path $ProjectPath "AGENT_RECOMMENDATIONS.md"
if (Test-Path -LiteralPath $recFileCheck) {
    try {
        $recText = [System.IO.File]::ReadAllText($recFileCheck, [System.Text.Encoding]::UTF8)
        $openRecs = ([regex]::Matches($recText, '\[ \]\s*ТРЕБУЕТ ВНЕДРЕНИЯ')).Count
        if ($openRecs -gt 0) {
            Write-Host "[REC-GUARD] 📌 В AGENT_RECOMMENDATIONS.md ожидают внедрения: $openRecs шт." -ForegroundColor Yellow
        }
    } catch {}
}

# 1. Определение категории проекта (Автоопределение или явное указание)
if ($Firmware) {
    $Category = "Firmware"
    $Release = $true
}

if ($Category -eq "Auto") {
    $isFirmwareProject = (Test-Path -LiteralPath (Join-Path $ProjectPath "platformio.ini")) -or 
                         (Get-ChildItem -LiteralPath $ProjectPath -Filter "*.ino" -ErrorAction SilentlyContinue) -or
                         (Get-ChildItem -LiteralPath $ProjectPath -Filter "*.ioc" -ErrorAction SilentlyContinue)

    $isDesktopProject = (Get-ChildItem -LiteralPath $ProjectPath -Filter "*.spec" -ErrorAction SilentlyContinue) -or
                        (Get-ChildItem -LiteralPath $ProjectPath -Filter "*.csproj" -ErrorAction SilentlyContinue) -or
                        (Get-ChildItem -LiteralPath $ProjectPath -Filter "*app.py" -ErrorAction SilentlyContinue) -or
                        (Get-ChildItem -LiteralPath $ProjectPath -Filter "*main.py" -ErrorAction SilentlyContinue)

    $isWebProject = (Test-Path -LiteralPath (Join-Path $ProjectPath "package.json")) -or 
                    (Test-Path -LiteralPath (Join-Path $ProjectPath "index.html")) -or
                    (Get-ChildItem -LiteralPath $ProjectPath -Filter "vite.config.*" -ErrorAction SilentlyContinue) -or
                    (Get-ChildItem -LiteralPath $ProjectPath -Filter "next.config.*" -ErrorAction SilentlyContinue)

    if ($isFirmwareProject) {
        $Category = "Firmware"
    } elseif ($isWebProject) {
        $Category = "Web"
    } elseif ($isDesktopProject) {
        $Category = "Desktop"
    } else {
        $Category = "Code"
    }
}

# 2. Формирование меток и папок
$now = Get-Date
$readableDate = $now.ToString("yyyy-MM-dd HH:mm:ss")
$timestamp = $now.ToString("yyyy-MM-dd_HH-mm-ss")

$backupRoot = Join-Path $ProjectPath ".backups"

$backupPrefix = "checkpoint"
$categoryEmoji = "🛡️"
$categoryTitle = "Чекпоинт Кода"

switch ($Category) {
    "Firmware" {
        if ($Release) {
            $backupPrefix = "firmware_success"
            $categoryEmoji = "🔥"
            $categoryTitle = "УДАЧНАЯ ПРОШИВКА (Firmware Flash)"
        } else {
            $backupPrefix = "checkpoint_firmware"
            $categoryEmoji = "🔥"
            $categoryTitle = "Чекпоинт проекта прошивки"
        }
    }
    "Desktop" {
        if ($Release) {
            $backupPrefix = "desktop_release"
            $categoryEmoji = "🖥️"
            $categoryTitle = "РЕЛИЗ ДЕСКТОП-ПРИЛОЖЕНИЯ (ПК / Desktop Build)"
        } else {
            $backupPrefix = "checkpoint_desktop"
            $categoryEmoji = "🖥️"
            $categoryTitle = "Чекпоинт десктоп-проекта"
        }
    }
    "Web" {
        if ($Release) {
            $backupPrefix = "web_release"
            $categoryEmoji = "🌐"
            $categoryTitle = "РЕЛИЗ ВЕБ-САЙТА (Web Production Build)"
        } else {
            $backupPrefix = "checkpoint_web"
            $categoryEmoji = "🌐"
            $categoryTitle = "Чекпоинт веб-проекта"
        }
    }
    default {
        $backupPrefix = "checkpoint"
        $categoryEmoji = "🛡️"
        $categoryTitle = "Универсальный чекпоинт кода"
    }
}

$currentBackupDir = Join-Path $backupRoot "${backupPrefix}_$timestamp"
if (Test-Path -LiteralPath $currentBackupDir) {
    $timestamp = $now.ToString("yyyy-MM-dd_HH-mm-ss_fff")
    $currentBackupDir = Join-Path $backupRoot "${backupPrefix}_$timestamp"
}

Write-Host "=== [Project Guardian] Резервная копия: $categoryEmoji $categoryTitle ===" -ForegroundColor Cyan
Write-Host "Проект: $ProjectPath"
Write-Host "Категория: $Category (Релизный архив: $Release)"
Write-Host "Сообщение: $Message"

# 2.5. Верификация тестов перед созданием бэкапа (-Verify)
if ($Verify) {
    Write-Host "`n=== [Project Guardian] Запуск верификации тестов (-Verify) ===" -ForegroundColor Cyan
    $testPassed = $true
    $testFound = $false

    $hasPyTestDir = (Test-Path -LiteralPath (Join-Path $ProjectPath "tests")) -or (Test-Path -LiteralPath (Join-Path $ProjectPath "test"))
    if ($hasPyTestDir) {
        $testFound = $true
    } else {
        $pyTestFiles = Get-ChildItem -LiteralPath $ProjectPath -Filter "test_*.py" -File -Depth 2 -ErrorAction SilentlyContinue | Where-Object {
            $_.FullName -notmatch "[\\/](\.git|\.backups|node_modules|\.venv|venv|scratch|graphify-out)[\\/]"
        }
        if ($pyTestFiles.Count -gt 0) { $testFound = $true }
    }

    if ($testFound) {
        Write-Host "Обнаружены тесты Python. Запуск тестов..." -ForegroundColor Gray
        $prevEAP = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $null = & python -c "import pytest" 2>$null
        if ($LASTEXITCODE -eq 0) {
            & python -m pytest $ProjectPath -q
            if ($LASTEXITCODE -ne 0) { $testPassed = $false }
        } else {
            & python -m unittest discover -s $ProjectPath -q 2>$null
            if ($LASTEXITCODE -ne 0) { $testPassed = $false }
        }
        $ErrorActionPreference = $prevEAP
    }

    $pkgJson = Join-Path $ProjectPath "package.json"
    if (-not $testFound -and (Test-Path -LiteralPath $pkgJson)) {
        try {
            $pkg = Get-Content -LiteralPath $pkgJson -Raw | ConvertFrom-Json
            if ($pkg.scripts.test -and $pkg.scripts.test -notmatch "no test specified") {
                $testFound = $true
                Write-Host "Обнаружен npm test. Запуск..." -ForegroundColor Gray
                $prevEAP = $ErrorActionPreference
                $ErrorActionPreference = "Continue"
                & npm test --prefix $ProjectPath --silent 2>$null
                if ($LASTEXITCODE -ne 0) { $testPassed = $false }
                $ErrorActionPreference = $prevEAP
            }
        } catch {}
    }

    if ($testFound) {
        if (-not $testPassed) {
            Write-Error "Верификация тестов провалена! Устраните ошибки перед сохранением чекпоинта."
            return
        } else {
            Write-Host "[OK] Все тесты успешно пройдены!" -ForegroundColor Green
        }
    } else {
        Write-Host "Тесты в проекте не обнаружены, проверка пропущена." -ForegroundColor Gray
    }
}

# 2.7. Обеспечиваем .gitignore и .graphifyignore ДО запуска Graphify и создания бэкапа
$gitignorePath = Join-Path $ProjectPath ".gitignore"
$giContent = if (Test-Path -LiteralPath $gitignorePath) { Get-Content -LiteralPath $gitignorePath -Raw -ErrorAction SilentlyContinue } else { "" }
$giAdded = @()
foreach ($ignoreLine in @(".backups/", "scratch/")) {
    $esc = [regex]::Escape($ignoreLine)
    if ($giContent -notmatch "(?m)^$esc\s*$") {
        $giAdded += $ignoreLine
    }
}
if ($giAdded.Count -gt 0) {
    $appendBlock = "`n" + ($giAdded -join "`n") + "`n"
    [System.IO.File]::AppendAllText($gitignorePath, $appendBlock, [System.Text.Encoding]::UTF8)
    Write-Host "Добавлены исключения в .gitignore: $($giAdded -join ', ')" -ForegroundColor Green
}

$graphifyIgnorePath = Join-Path $ProjectPath ".graphifyignore"
if (-not (Test-Path -LiteralPath $graphifyIgnorePath)) {
    $gIgnoreContent = ".backups/`nscratch/`nnode_modules/`n.venv/`nvenv/`n__pycache__/`ndist/`nbuild/`n.git/`n"
    [System.IO.File]::WriteAllText($graphifyIgnorePath, $gIgnoreContent, (New-Object System.Text.UTF8Encoding $false))
}

# 2.8. Своевременное обновление даты в PROJECT_STATE.md (ДО создания снимка бэкапа и ДО git commit)
$stateFile = Join-Path $ProjectPath "PROJECT_STATE.md"
if (Test-Path -LiteralPath $stateFile) {
    try {
        $stateContent = Get-Content -LiteralPath $stateFile -Raw -Encoding UTF8
        $entryPrefix = switch ($Category) {
            "Firmware" { if ($Release) { "🔥 **УДАЧНАЯ ПРОШИВКА**" } else { "🔥 **Чекпоинт (Прошивка)**" } }
            "Desktop"  { if ($Release) { "🖥️ **РЕЛИЗ ДЕСКТОП-ПРИЛОЖЕНИЯ**" } else { "🖥️ **Чекпоинт (ПК)**" } }
            "Web"      { if ($Release) { "🌐 **РЕЛИЗ ВЕБ-САЙТА**" } else { "🌐 **Чекпоинт (Web)**" } }
            default    { "🛡️ **Чекпоинт**" }
        }
        $logEntry = "`n- $entryPrefix [$readableDate] (метка: $timestamp): $Message"
        if ($stateContent -match "(## (?:\d+\.\s*)?История Изменений[^\r\n]*)") {
            $stateContent = $stateContent -replace "(## (?:\d+\.\s*)?История Изменений[^\r\n]*)", "`$1`n$logEntry"
            [System.IO.File]::WriteAllText($stateFile, $stateContent, [System.Text.Encoding]::UTF8)
            Write-Host "[OK] Запись добавлена в PROJECT_STATE.md" -ForegroundColor Green
        }
    } catch {
        Write-Warning "Не удалось обновить PROJECT_STATE.md: $_"
    }
}

# 2.9. Автоматическая инициализация и инкрементальное обновление графа знаний (Graphify v1.8.0)
if (-not $NoGraphify -and -not $isCompositeRoot) {
    $graphifyJson = Join-Path $ProjectPath "graphify-out\graph.json"
    Write-Host "`n=== Граф Знаний (Graphify) ===" -ForegroundColor Cyan
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $pyCmd = Get-Command python -ErrorAction SilentlyContinue
        if ($pyCmd) {
            Push-Location -LiteralPath $ProjectPath
            try {
                if (Test-Path -LiteralPath $graphifyJson) {
                    Write-Host "Инкрементальное обновление графа (graphify update)..." -ForegroundColor Gray
                    $gOut = & $pyCmd.Source -m graphify update $ProjectPath 2>&1
                } else {
                    Write-Host "Первичная инициализация графа кода (graphify extract --code-only)..." -ForegroundColor Gray
                    $gOut = & $pyCmd.Source -m graphify extract $ProjectPath --code-only 2>&1
                }
                if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $graphifyJson)) {
                    Write-Host "[OK] Граф знаний graphify актуален: $graphifyJson" -ForegroundColor Green
                } else {
                    Write-Host "[!] Graphify завершился с кодом $LASTEXITCODE (возможно, нет поддерживаемых файлов кода)." -ForegroundColor Yellow
                }
            } finally {
                Pop-Location
            }
        }
    } catch {
        Write-Warning "Не удалось обновить graphify: $_"
    } finally {
        $ErrorActionPreference = $prevEAP
    }
}

# 3. Создание бэкапа
try {
    if (-not (Test-Path -LiteralPath $backupRoot)) {
        New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    }

    New-Item -ItemType Directory -Path $currentBackupDir -Force | Out-Null

    $excludeDirs = @(".git", ".backups", "node_modules", ".venv", "venv", "__pycache__", "dist", "build", ".next", ".nuxt", ".turbo", "bin", "obj", "scratch", "graphify-out")

    if (-not $IncludeSubprojects) {
        $nestedSubProjects = @(Get-ChildItem -LiteralPath $ProjectPath -Directory -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -notmatch '^(\.git|\.backups|node_modules|\.venv|venv|scratch|graphify-out)$' -and
            (Test-Path -LiteralPath (Join-Path $_.FullName "PROJECT_STATE.md"))
        })
        foreach ($nsp in $nestedSubProjects) {
            $excludeDirs += $nsp.Name
        }
    }

    $items = Get-ChildItem -LiteralPath $ProjectPath -Force | Where-Object { $excludeDirs -notcontains $_.Name }
    foreach ($item in $items) {
        Copy-Item -LiteralPath $item.FullName -Destination $currentBackupDir -Recurse -Force
    }

    # 4. Сохранение релизных артефактов в зависимости от категории
    $savedArtifacts = @()

    if ($Category -eq "Firmware" -and $Release) {
        $firmwareBinDir = Join-Path $currentBackupDir "firmware_binaries"
        New-Item -ItemType Directory -Path $firmwareBinDir -Force | Out-Null
        $binExtensions = @("*.bin", "*.hex", "*.elf", "*.uf2", "*.dfu", "*.img", "*.ota")
        $foundBinaries = Get-ChildItem -LiteralPath $ProjectPath -Recurse -Include $binExtensions -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notlike "*\.backups\*" }

        foreach ($bin in $foundBinaries) {
            Copy-Item -LiteralPath $bin.FullName -Destination (Join-Path $firmwareBinDir $bin.Name) -Force
            $hash = (Get-FileHash -LiteralPath $bin.FullName -Algorithm SHA256).Hash
            $savedArtifacts += [PSCustomObject]@{ Name = $bin.Name; SizeKB = [math]::Round($bin.Length / 1KB, 2); SHA256 = $hash }
            Write-Host "  [Бинарник сохранен]: $($bin.Name) ($([math]::Round($bin.Length / 1KB, 2)) KB)" -ForegroundColor Magenta
        }
    }
    elseif ($Category -eq "Desktop" -and $Release) {
        $desktopBinDir = Join-Path $currentBackupDir "desktop_binaries"
        New-Item -ItemType Directory -Path $desktopBinDir -Force | Out-Null
        $exeExtensions = @("*.exe", "*.msi", "*.dll", "*.zip")
        $foundExes = Get-ChildItem -LiteralPath $ProjectPath -Recurse -Include $exeExtensions -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notlike "*\.backups\*" -and $_.FullName -notlike "*\node_modules\*" -and $_.FullName -notlike "*\.venv\*" }

        foreach ($f in $foundExes) {
            Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $desktopBinDir $f.Name) -Force
            $hash = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash
            $savedArtifacts += [PSCustomObject]@{ Name = $f.Name; SizeKB = [math]::Round($f.Length / 1KB, 2); SHA256 = $hash }
            Write-Host "  [Десктоп бинарник/EXE сохранен]: $($f.Name) ($([math]::Round($f.Length / 1KB, 2)) KB)" -ForegroundColor Magenta
        }
    }
    elseif ($Category -eq "Web" -and $Release) {
        $webDistDir = Join-Path $currentBackupDir "web_artifacts"
        New-Item -ItemType Directory -Path $webDistDir -Force | Out-Null
        $distFolders = @("dist", "build", "out")
        foreach ($df in $distFolders) {
            $srcDist = Join-Path $ProjectPath $df
            if (Test-Path -LiteralPath $srcDist) {
                Copy-Item -LiteralPath $srcDist -Destination (Join-Path $webDistDir $df) -Recurse -Force
                Write-Host "  [Веб-сборка сохранена]: $df" -ForegroundColor Magenta
            }
        }
    }

    if ($Release) {
        $passportContent = @"
# Паспорт релиза: $backupPrefix [$timestamp]

- **Категория**: $Category
- **Дата и время**: $readableDate
- **Описание**: $Message
- **Папка архива**: $currentBackupDir

## Сохраненные артефакты:
"@
        if ($savedArtifacts.Count -gt 0) {
            foreach ($a in $savedArtifacts) {
                $passportContent += "`n- **$($a.Name)** ($($a.SizeKB) KB) | SHA256: ``$($a.SHA256)``"
            }
        } else {
            $passportContent += "`n*(Полный снимок рабочего исходного кода сохранен без перезаписи)*"
        }

        $passportFile = Join-Path $currentBackupDir "RELEASE_INFO.md"
        [System.IO.File]::WriteAllText($passportFile, $passportContent, [System.Text.Encoding]::UTF8)
        Write-Host "[OK] Паспорт релиза создан: RELEASE_INFO.md" -ForegroundColor Green
    }

    Write-Host "[OK] Резервная копия сохранена в: $currentBackupDir" -ForegroundColor Green
}
catch {
    Write-Warning "Не удалось создать файловый бэкап в .backups: $_"
}

# 5. Обработка Git (с Auto-Git-Init для одиночных проектов)
$isGit = $false
$prevEAP = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $gitCheck = & git -C $ProjectPath rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -eq 0 -and $gitCheck -and $gitCheck.Trim() -eq "true") {
        $isGit = $true
    } elseif (-not $isCompositeRoot) {
        $gitCmd = Get-Command git -ErrorAction SilentlyContinue
        if ($gitCmd) {
            & git -C $ProjectPath init 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $isGit = $true
                Write-Host "[Project Guardian] 🆕 Автоматически инициализирован локальный Git-репозиторий (git init)." -ForegroundColor Cyan
            }
        }
    }
} catch {
    $isGit = $false
}
$ErrorActionPreference = $prevEAP

if ($isGit) {
    Write-Host "`n=== Обработка Git ===" -ForegroundColor Cyan
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & git -C $ProjectPath add -A 2>$null
        $status = & git -C $ProjectPath status --porcelain 2>$null
        $tagPrefix = $Category.ToLower()

        $commitPrefix = switch ($Category) {
            "Firmware" { if ($Release) { "firmware: [SUCCESS FLASH]" } else { "firmware: [checkpoint]" } }
            "Desktop"  { if ($Release) { "desktop: [RELEASE BUILD]" } else { "desktop: [checkpoint]" } }
            "Web"      { if ($Release) { "web: [PRODUCTION BUILD]" } else { "web: [checkpoint]" } }
            default    { "checkpoint:" }
        }
        $fullCommitMsg = "$commitPrefix $Message [$timestamp]"

        if ($status) {
            & git -C $ProjectPath commit -m "$fullCommitMsg"
            Write-Host "[OK] Изменения зафиксированы в коммите: $fullCommitMsg" -ForegroundColor Green
        } else {
            Write-Host "В Git нет незафиксированных изменений рабочего дерева." -ForegroundColor Yellow
        }

        if ($Release) {
            $tagName = "$tagPrefix-v$timestamp"
            & git -C $ProjectPath tag -a $tagName -m "Релиз ($Category): $Message ($readableDate)"
            Write-Host "[OK] Создан уникальный Git-тег: $tagName" -ForegroundColor Magenta
        }

        $remotes = & git -C $ProjectPath remote 2>$null
        if ($remotes -and $Push -and -not $NoPush) {
            $currentBranch = (& git -C $ProjectPath rev-parse --abbrev-ref HEAD 2>$null).Trim()
            if ($currentBranch -and $currentBranch -ne "HEAD") {
                Write-Host "Отправка изменений в origin/$currentBranch..." -ForegroundColor Cyan
                & git -C $ProjectPath push origin $currentBranch
                if ($Release) {
                    & git -C $ProjectPath push origin --tags
                }
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "[OK] Успешно отправлено в Git remote (origin/$currentBranch)" -ForegroundColor Green
                } else {
                    Write-Warning "Не удалось выполнить git push. Проверьте права доступа и состояние ветки."
                }
            }
        } elseif (-not $remotes) {
            Write-Host "Git remote не настроен. Коммит сохранен локально." -ForegroundColor Gray
        } else {
            Write-Host "Коммит сохранён локально. Пуш не выполнялся (нужен явный -Push)." -ForegroundColor Gray
        }
    }
    catch {
        Write-Warning "Ошибка при выполнении операций Git: $_"
    } finally {
        $ErrorActionPreference = $prevEAP
    }
} else {
    Write-Host "Папка не является Git-репозиторием. Локальный бэкап успешно создан." -ForegroundColor Gray
}

Write-Host "`nРезервное копирование завершено успешно! Архив сохранен без перезаписи." -ForegroundColor Green
