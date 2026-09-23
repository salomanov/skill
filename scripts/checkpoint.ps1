param(
    [string]$Message = "Automatic checkpoint",
    [switch]$Push = $true,
    [switch]$Firmware = $false,
    [string]$ProjectPath = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

$typeTitle = if ($Firmware) { "УДАЧНАЯ ПРОШИВКА (Firmware Flash - Отдельный архив)" } else { "Контрольная точка (Checkpoint)" }
Write-Host "=== [Project Guardian] Создание резервной копии: $typeTitle ===" -ForegroundColor Cyan
Write-Host "Проект: $ProjectPath"
Write-Host "Сообщение: $Message"

# 1. Формирование уникального штампа даты и времени
$now = Get-Date
$readableDate = $now.ToString("yyyy-MM-dd HH:mm:ss")
$timestamp = $now.ToString("yyyy-MM-dd_HH-mm-ss")

$backupRoot = Join-Path $ProjectPath ".backups"
$backupPrefix = if ($Firmware) { "firmware_success" } else { "checkpoint" }
$currentBackupDir = Join-Path $backupRoot "${backupPrefix}_$timestamp"

# Гарантия от перезаписи: если по какой-то причине папка с такой секундой существует, добавляем миллисекунды
if (Test-Path $currentBackupDir) {
    $timestamp = $now.ToString("yyyy-MM-dd_HH-mm-ss_fff")
    $currentBackupDir = Join-Path $backupRoot "${backupPrefix}_$timestamp"
}

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

    # Создаем новую уникальную папку бэкапа (никогда не перезаписывает старые)
    New-Item -ItemType Directory -Path $currentBackupDir -Force | Out-Null

    # Список исключений для базового копирования
    $excludeDirs = @(".git", ".backups", "node_modules", ".venv", "venv", "__pycache__", "dist", "build", ".next", ".turbo")

    # Копируем исходный код проекта в архив
    $items = Get-ChildItem -Path $ProjectPath -Force | Where-Object { $excludeDirs -notcontains $_.Name }
    foreach ($item in $items) {
        Copy-Item -Path $item.FullName -Destination $currentBackupDir -Recurse -Force
    }

    # Если это отдельный бэкап прошивки — сохраняем бинарники и создаем паспорт прошивки
    if ($Firmware) {
        $firmwareBinDir = Join-Path $currentBackupDir "firmware_binaries"
        New-Item -ItemType Directory -Path $firmwareBinDir -Force | Out-Null

        $binExtensions = @("*.bin", "*.hex", "*.elf", "*.uf2", "*.dfu", "*.img", "*.ota")
        $foundBinaries = Get-ChildItem -Path $ProjectPath -Recurse -Include $binExtensions -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notlike "*\.backups\*" }

        $savedBinInfo = @()
        if ($foundBinaries) {
            foreach ($bin in $foundBinaries) {
                $targetFile = Join-Path $firmwareBinDir $bin.Name
                Copy-Item -Path $bin.FullName -Destination $targetFile -Force
                $hash = (Get-FileHash -Path $bin.FullName -Algorithm SHA256).Hash
                $savedBinInfo += [PSCustomObject]@{
                    Name = $bin.Name
                    SizeKB = [math]::Round($bin.Length / 1KB, 2)
                    SHA256 = $hash
                }
                Write-Host "  [Бинарник сохранен]: $($bin.Name) ($([math]::Round($bin.Length / 1KB, 2)) KB)" -ForegroundColor Magenta
            }
        }

        # Создаем паспорт прошивки FIRMWARE_INFO.md внутри отдельного архива
        $firmwareInfoContent = @"
# Паспорт удачной прошивки: $timestamp

- **Дата и время прошивки**: $readableDate
- **Описание / Версия**: $Message
- **Директория архива**: $currentBackupDir

## Сохраненные бинарники:
"@
        if ($savedBinInfo.Count -gt 0) {
            foreach ($b in $savedBinInfo) {
                $firmwareInfoContent += "`n- **$($b.Name)** ($($b.SizeKB) KB) | SHA256: ``$($b.SHA256)``"
            }
        } else {
            $firmwareInfoContent += "`n*(Бинарные файлы в проекте не обнаружены, сохранен полный слепок исходного кода на момент прошивки)*"
        }

        $firmwareInfoFile = Join-Path $currentBackupDir "FIRMWARE_INFO.md"
        [System.IO.File]::WriteAllText($firmwareInfoFile, $firmwareInfoContent, [System.Text.Encoding]::UTF8)

        Write-Host "[OK] Создан отдельный несгораемый архив прошивки: $currentBackupDir" -ForegroundColor Green
    } else {
        Write-Host "[OK] Резервная копия сохранена в: $currentBackupDir" -ForegroundColor Green
    }
}
catch {
    Write-Warning "Не удалось создать файловый бэкап в .backups: $_"
}

# 2. Обработка Git
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
        $commitPrefix = if ($Firmware) { "firmware: [SUCCESS FLASH]" } else { "checkpoint:" }
        $fullCommitMsg = "$commitPrefix $Message [$timestamp]"

        if ($status) {
            & git -C $ProjectPath commit -m "$fullCommitMsg"
            Write-Host "[OK] Изменения зафиксированы в коммите: $fullCommitMsg" -ForegroundColor Green
        } else {
            Write-Host "В Git нет незафиксированных изменений рабочего дерева." -ForegroundColor Yellow
        }

        # Если это прошивка, создаем уникальный тег с датой и временем
        if ($Firmware) {
            $tagName = "firmware-flash-$timestamp"
            & git -C $ProjectPath tag -a $tagName -m "Удачная прошивка: $Message ($readableDate)"
            Write-Host "[OK] Создан уникальный Git-тег: $tagName" -ForegroundColor Magenta
        }

        # Проверка remote для push
        $remotes = & git -C $ProjectPath remote
        if ($remotes -and $Push) {
            $currentBranch = (& git -C $ProjectPath rev-parse --abbrev-ref HEAD).Trim()
            if ($currentBranch -and $currentBranch -ne "HEAD") {
                Write-Host "Отправка изменений в origin/$currentBranch..." -ForegroundColor Cyan
                & git -C $ProjectPath push origin $currentBranch
                if ($Firmware) {
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
        }
    }
    catch {
        Write-Warning "Ошибка при выполнении операций Git: $_"
    }
} else {
    Write-Host "Папка не является Git-репозиторием. Локальный бэкап успешно создан." -ForegroundColor Gray
}

# 3. Обновление даты в PROJECT_STATE.md
$stateFile = Join-Path $ProjectPath "PROJECT_STATE.md"
if (Test-Path $stateFile) {
    try {
        $stateContent = Get-Content $stateFile -Raw -Encoding UTF8
        $entryPrefix = if ($Firmware) { "🔥 **УДАЧНАЯ ПРОШИВКА**" } else { "**Чекпоинт**" }
        $logEntry = "`n- $entryPrefix [$readableDate] (метка: $timestamp): $Message"
        if ($stateContent -match "(## 5\. История Изменений[^\r\n]*)") {
            $stateContent = $stateContent -replace "(## 5\. История Изменений[^\r\n]*)", "`$1`n$logEntry"
            [System.IO.File]::WriteAllText($stateFile, $stateContent, [System.Text.Encoding]::UTF8)
            Write-Host "[OK] Запись добавлена в PROJECT_STATE.md" -ForegroundColor Green
        }
    } catch {
        Write-Warning "Не удалось обновить PROJECT_STATE.md: $_"
    }
}

Write-Host "`nРезервное копирование завершено успешно! Архив сохранен навсегда." -ForegroundColor Green
