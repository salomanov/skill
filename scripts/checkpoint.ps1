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

# --- Mechanical Step Counter & Context Hygiene Guard (Project Guardian v1.7.9) ---
function Get-ActiveSessionStepCount {
    [CmdletBinding()]
    param()

    $brainRoot = Join-Path $HOME '.gemini/antigravity/brain'
    $threshold = 180

    if (-not (Test-Path -LiteralPath $brainRoot -PathType Container)) { return 0 }

    $activeDir = Get-ChildItem -LiteralPath $brainRoot -Directory -Force -ErrorAction SilentlyContinue |
                 Sort-Object -Property LastWriteTime -Descending |
                 Select-Object -First 1

    if ($null -eq $activeDir) { return 0 }

    $transcript = Join-Path $activeDir.FullName '.system_generated/logs/transcript.jsonl'
    if (-not (Test-Path -LiteralPath $transcript -PathType Leaf)) { return 0 }

    $stepCount = 0
    $reader = $null
    try {
        $reader = [System.IO.StreamReader]::new($transcript)
        while ($null -ne $reader.ReadLine()) { $stepCount++ }
    }
    catch { return 0 }
    finally { if ($null -ne $reader) { $reader.Dispose() } }

    if ($stepCount -ge $threshold) {
        $w = 78
        $border = '#' * $w
        $row = '#   {0,-72} #'

        Write-Host ''
        Write-Host $border -ForegroundColor Red
        Write-Host ($row -f '') -ForegroundColor Red
        Write-Host ($row -f '!!! MECHANICAL STEP COUNTER :: CONTEXT HYGIENE GUARD !!!') -ForegroundColor Red
        Write-Host ($row -f '') -ForegroundColor Red
        Write-Host ($row -f "Сессия: $($activeDir.Name)") -ForegroundColor Red
        Write-Host ($row -f "Шагов в логе: $stepCount (порог перегрузки >= $threshold)") -ForegroundColor Red
        Write-Host ($row -f '') -ForegroundColor Red
        Write-Host ($row -f '>>> ВНИМАНИЕ: СРОЧНО ЗАПУСТИТЬ prepare-handoff.ps1 И СМЕНИТЬ ДИАЛОГ! <<<') -ForegroundColor Red
        Write-Host ($row -f 'Во избежание когнитивной деградации агента продолжите работу в новом чате.') -ForegroundColor Red
        Write-Host ($row -f '') -ForegroundColor Red
        Write-Host $border -ForegroundColor Red
        Write-Host ''
    }

    return $stepCount
}

$activeSteps = Get-ActiveSessionStepCount

# 0. Нормализация пути и автоопределение подпроекта в составных воркспейсах
if ($ProjectPath -and (Test-Path $ProjectPath)) {
    $ProjectPath = (Resolve-Path $ProjectPath).Path
}

if ($SubProject) {
    $candidateSub = Join-Path $ProjectPath $SubProject
    if (Test-Path $candidateSub) {
        $ProjectPath = (Resolve-Path $candidateSub).Path
        Write-Host "[Project Guardian] 🎯 Выбран подпроект: $ProjectPath" -ForegroundColor Cyan
    } else {
        Write-Warning "Указанный подпроект '$SubProject' не найден в $ProjectPath"
    }
} else {
    # Проверяем, является ли $ProjectPath контейнером нескольких подпроектов (каждый со своим PROJECT_STATE.md)
    $subProjects = @(Get-ChildItem -Path $ProjectPath -Directory -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -notmatch '^(\.git|\.backups|node_modules|\.venv|venv|scratch)$' -and
        (Test-Path (Join-Path $_.FullName "PROJECT_STATE.md"))
    })

    if ($subProjects.Count -gt 0) {
        # Пытаемся определить активный подпроект по незакоммиченным файлам в Git
        $gitSub = $null
        try {
            $gitStatus = & git -C $ProjectPath status --porcelain 2>$null
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
            $spName = Split-Path $ProjectPath -Leaf
            Write-Host "[Project Guardian] 🎯 Автоопределение: активный подпроект '$spName' (по изменениям Git)." -ForegroundColor Cyan
            Write-Host "   Чекпоинт создается изолированно в $ProjectPath\.backups" -ForegroundColor Gray
        } else {
            Write-Host "[Project Guardian] ℹ️ Составной воркспейс с подпроектами: $($subProjects.Name -join ', ')" -ForegroundColor DarkCyan
            Write-Host "   Для изолированного чекпоинта подпроекта передайте: -ProjectPath <путь> или -SubProject <имя>" -ForegroundColor Gray
        }
    }
}

# 1. Определение категории проекта (Автоопределение или явное указание)
if ($Firmware) {
    $Category = "Firmware"
    $Release = $true
}

if ($Category -eq "Auto") {
    # Поиск маркеров микроконтроллеров/прошивок
    $isFirmwareProject = (Test-Path (Join-Path $ProjectPath "platformio.ini")) -or 
                         (Get-ChildItem -Path $ProjectPath -Filter "*.ino" -ErrorAction SilentlyContinue) -or
                         (Get-ChildItem -Path $ProjectPath -Filter "*.ioc" -ErrorAction SilentlyContinue)

    # Поиск маркеров десктопных приложений для ПК
    $isDesktopProject = (Get-ChildItem -Path $ProjectPath -Filter "*.spec" -ErrorAction SilentlyContinue) -or
                        (Get-ChildItem -Path $ProjectPath -Filter "*.csproj" -ErrorAction SilentlyContinue) -or
                        (Get-ChildItem -Path $ProjectPath -Filter "*app.py" -ErrorAction SilentlyContinue) -or
                        (Get-ChildItem -Path $ProjectPath -Filter "*main.py" -ErrorAction SilentlyContinue)

    # Поиск маркеров веб-сайтов и веб-приложений
    $isWebProject = (Test-Path (Join-Path $ProjectPath "package.json")) -or 
                    (Test-Path (Join-Path $ProjectPath "index.html")) -or
                    (Test-Path (Join-Path $ProjectPath "vite.config.*")) -or
                    (Test-Path (Join-Path $ProjectPath "next.config.*"))

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
if (Test-Path $currentBackupDir) {
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

    # Проверка Python тестов: папка tests/ или test/, либо файлы в корне (без тяжелой рекурсии)
    $hasPyTestDir = (Test-Path (Join-Path $ProjectPath "tests")) -or (Test-Path (Join-Path $ProjectPath "test"))
    $pyTestFiles = @()
    if ($hasPyTestDir) {
        $testFound = $true
    } else {
        $pyTestFiles = Get-ChildItem -Path $ProjectPath -Filter "test_*.py" -File -Depth 2 -ErrorAction SilentlyContinue | Where-Object {
            $_.FullName -notmatch "[\\/](\.git|\.backups|node_modules|\.venv|venv|scratch)[\\/]"
        }
        if ($pyTestFiles.Count -gt 0) { $testFound = $true }
    }

    if ($testFound) {
        Write-Host "Обнаружены тесты Python. Запуск тестов..." -ForegroundColor Gray
        $null = & python -c "import pytest" 2>$null
        if ($LASTEXITCODE -eq 0) {
            & python -m pytest $ProjectPath -q
            if ($LASTEXITCODE -ne 0) { $testPassed = $false }
        } else {
            & python -m unittest discover -s $ProjectPath -q 2>$null
            if ($LASTEXITCODE -ne 0) { $testPassed = $false }
        }
    }

    # Проверка npm test
    $pkgJson = Join-Path $ProjectPath "package.json"
    if (-not $testFound -and (Test-Path $pkgJson)) {
        try {
            $pkg = Get-Content $pkgJson -Raw | ConvertFrom-Json
            if ($pkg.scripts.test -and $pkg.scripts.test -notmatch "no test specified") {
                $testFound = $true
                Write-Host "Обнаружен npm test. Запуск..." -ForegroundColor Gray
                & npm test --prefix $ProjectPath --silent 2>$null
                if ($LASTEXITCODE -ne 0) { $testPassed = $false }
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

# 2.8. Своевременное обновление даты в PROJECT_STATE.md (ДО создания снимка бэкапа и ДО git commit)
$stateFile = Join-Path $ProjectPath "PROJECT_STATE.md"
if (Test-Path $stateFile) {
    try {
        $stateContent = Get-Content $stateFile -Raw -Encoding UTF8
        $entryPrefix = switch ($Category) {
            "Firmware" { if ($Release) { "🔥 **УДАЧНАЯ ПРОШИВКА**" } else { "🔥 **Чекпоинт (Прошивка)**" } }
            "Desktop"  { if ($Release) { "🖥️ **РЕЛИЗ ДЕСКТОП-ПРИЛОЖЕНИЯ**" } else { "🖥️ **Чекпоинт (ПК)**" } }
            "Web"      { if ($Release) { "🌐 **РЕЛИЗ ВЕБ-САЙТА**" } else { "🌐 **Чекпоинт (Web)**" } }
            default    { "🛡️ **Чекпоинт**" }
        }
        $logEntry = "`n- $entryPrefix [$readableDate] (метка: $timestamp): $Message"
        # Поддержка как старого формата (## 5.), так и нового эталонного шаблона (## 10. или любого номера)
        if ($stateContent -match "(## (?:\d+\.\s*)?История Изменений[^\r\n]*)") {
            $stateContent = $stateContent -replace "(## (?:\d+\.\s*)?История Изменений[^\r\n]*)", "`$1`n$logEntry"
            [System.IO.File]::WriteAllText($stateFile, $stateContent, [System.Text.Encoding]::UTF8)
            Write-Host "[OK] Запись добавлена в PROJECT_STATE.md" -ForegroundColor Green
        }
    } catch {
        Write-Warning "Не удалось обновить PROJECT_STATE.md: $_"
    }
}

# 2.9. Автоматическое обновление графа знаний (graphify)
$graphifyDir = Join-Path $ProjectPath "graphify-out"
if ((Test-Path $graphifyDir) -and (-not $NoGraphify)) {
    Write-Host "`n=== Обновление Графа Знаний (Graphify) ===" -ForegroundColor Cyan
    try {
        $pyCmd = Get-Command python -ErrorAction SilentlyContinue
        if ($pyCmd) {
            Write-Host "Инкрементальный анализ кодовой базы через graphify..." -ForegroundColor Gray
            & $pyCmd.Source -m graphify extract $ProjectPath --code-only 2>$null
            & $pyCmd.Source -m graphify cluster-only $ProjectPath 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[OK] Граф знаний graphify успешно актуализирован!" -ForegroundColor Green
            } else {
                Write-Host "[!] Завершено с кодом $LASTEXITCODE" -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Warning "Не удалось обновить graphify: $_"
    }
}

# 3. Создание бэкапа
try {
    if (-not (Test-Path $backupRoot)) {
        New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    }

    # Обеспечиваем наличие .backups в .gitignore
    $gitignorePath = Join-Path $ProjectPath ".gitignore"
    $needGitignoreUpdate = $true
    if (Test-Path $gitignorePath) {
        $giContent = Get-Content $gitignorePath -Raw -ErrorAction SilentlyContinue
        if ($giContent -match "^\.backups/" -or $giContent -match "\r?\n\.backups/") {
            $needGitignoreUpdate = $false
        }
    }
    if ($needGitignoreUpdate) {
        Add-Content -Path $gitignorePath -Value "`n.backups/" -Encoding UTF8
        Write-Host "Добавлена запись .backups/ в .gitignore" -ForegroundColor Green
    }

    # Создаем изолированную директорию (никогда не перезаписывает старые)
    New-Item -ItemType Directory -Path $currentBackupDir -Force | Out-Null

    # Исключения зависимостей и временных файлов
    $excludeDirs = @(".git", ".backups", "node_modules", ".venv", "venv", "__pycache__", "dist", "build", ".next", ".nuxt", ".turbo", "bin", "obj", "scratch")

    # Если мы находимся в корне составного воркспейса, исключаем вложенные подпроекты, чтобы не дублировать гигабайты
    if (-not $IncludeSubprojects) {
        $nestedSubProjects = @(Get-ChildItem -Path $ProjectPath -Directory -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -notmatch '^(\.git|\.backups|node_modules|\.venv|venv|scratch)$' -and
            (Test-Path (Join-Path $_.FullName "PROJECT_STATE.md"))
        })
        foreach ($nsp in $nestedSubProjects) {
            $excludeDirs += $nsp.Name
        }
    }

    # Копирование исходников
    $items = Get-ChildItem -Path $ProjectPath -Force | Where-Object { $excludeDirs -notcontains $_.Name }
    foreach ($item in $items) {
        Copy-Item -Path $item.FullName -Destination $currentBackupDir -Recurse -Force
    }

    # 4. Сохранение релизных артефактов в зависимости от категории
    $savedArtifacts = @()

    if ($Category -eq "Firmware" -and $Release) {
        $firmwareBinDir = Join-Path $currentBackupDir "firmware_binaries"
        New-Item -ItemType Directory -Path $firmwareBinDir -Force | Out-Null
        $binExtensions = @("*.bin", "*.hex", "*.elf", "*.uf2", "*.dfu", "*.img", "*.ota")
        $foundBinaries = Get-ChildItem -Path $ProjectPath -Recurse -Include $binExtensions -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notlike "*\.backups\*" }

        foreach ($bin in $foundBinaries) {
            Copy-Item -Path $bin.FullName -Destination (Join-Path $firmwareBinDir $bin.Name) -Force
            $hash = (Get-FileHash -Path $bin.FullName -Algorithm SHA256).Hash
            $savedArtifacts += [PSCustomObject]@{ Name = $bin.Name; SizeKB = [math]::Round($bin.Length / 1KB, 2); SHA256 = $hash }
            Write-Host "  [Бинарник сохранен]: $($bin.Name) ($([math]::Round($bin.Length / 1KB, 2)) KB)" -ForegroundColor Magenta
        }
    }
    elseif ($Category -eq "Desktop" -and $Release) {
        $desktopBinDir = Join-Path $currentBackupDir "desktop_binaries"
        New-Item -ItemType Directory -Path $desktopBinDir -Force | Out-Null
        $exeExtensions = @("*.exe", "*.msi", "*.dll", "*.zip")
        # Ищем в dist/ и корне
        $foundExes = Get-ChildItem -Path $ProjectPath -Recurse -Include $exeExtensions -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notlike "*\.backups\*" -and $_.FullName -notlike "*\node_modules\*" -and $_.FullName -notlike "*\.venv\*" }

        foreach ($f in $foundExes) {
            Copy-Item -Path $f.FullName -Destination (Join-Path $desktopBinDir $f.Name) -Force
            $hash = (Get-FileHash -Path $f.FullName -Algorithm SHA256).Hash
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
            if (Test-Path $srcDist) {
                Copy-Item -Path $srcDist -Destination (Join-Path $webDistDir $df) -Recurse -Force
                Write-Host "  [Веб-сборка сохранена]: $df" -ForegroundColor Magenta
            }
        }
    }

    # Генерация паспорта релиза
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

# 5. Обработка Git
$isGit = $false
try {
    $gitCheck = & git -C $ProjectPath rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -eq 0 -and $gitCheck.Trim() -eq "true") {
        $isGit = $true
    }
} catch {
    $isGit = $false
}

if ($isGit) {
    Write-Host "`n=== Обработка Git ===" -ForegroundColor Cyan
    try {
        & git -C $ProjectPath add -A
        $status = & git -C $ProjectPath status --porcelain
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

        # Если это релиз или прошивка — создаем уникальный Git-тег с датой и временем
        if ($Release) {
            $tagName = "$tagPrefix-v$timestamp"
            & git -C $ProjectPath tag -a $tagName -m "Релиз ($Category): $Message ($readableDate)"
            Write-Host "[OK] Создан уникальный Git-тег: $tagName" -ForegroundColor Magenta
        }

        # Проверка remote для push (только по явному -Push)
        $remotes = & git -C $ProjectPath remote
        if ($remotes -and $Push -and -not $NoPush) {
            $currentBranch = (& git -C $ProjectPath rev-parse --abbrev-ref HEAD).Trim()
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
    }
} else {
    Write-Host "Папка не является Git-репозиторием. Локальный бэкап успешно создан." -ForegroundColor Gray
}

Write-Host "`nРезервное копирование завершено успешно! Архив сохранен без перезаписи." -ForegroundColor Green
