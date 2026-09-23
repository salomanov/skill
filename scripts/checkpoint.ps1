param(
    [string]$Message = "Automatic checkpoint",
    [switch]$Push = $true,
    [string]$ProjectPath = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

Write-Host "=== [Project Guardian] Создание контрольной точки ===" -ForegroundColor Cyan
Write-Host "Проект: $ProjectPath"
Write-Host "Сообщение: $Message"

# 1. Создание локальной резервной копии в .backups
$timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$backupRoot = Join-Path $ProjectPath ".backups"
$currentBackupDir = Join-Path $backupRoot "checkpoint_$timestamp"

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

    # Создаем папку бэкапа
    New-Item -ItemType Directory -Path $currentBackupDir -Force | Out-Null

    # Список исключений для бэкапа (крупные папки зависимостей и VCS)
    $excludeDirs = @(".git", ".backups", "node_modules", ".venv", "venv", "__pycache__", "dist", "build", ".next", ".turbo")

    # Копируем проект в бэкап
    $items = Get-ChildItem -Path $ProjectPath -Force | Where-Object { $excludeDirs -notcontains $_.Name }
    foreach ($item in $items) {
        Copy-Item -Path $item.FullName -Destination $currentBackupDir -Recurse -Force
    }
    Write-Host "[OK] Резервная копия сохранена в: $currentBackupDir" -ForegroundColor Green
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
        if ($status) {
            & git -C $ProjectPath commit -m "$Message [checkpoint: $timestamp]"
            Write-Host "[OK] Изменения зафиксированы в коммите: $Message" -ForegroundColor Green
        } else {
            Write-Host "В Git нет незафиксированных изменений." -ForegroundColor Yellow
        }

        # Проверка remote для push
        $remotes = & git -C $ProjectPath remote
        if ($remotes -and $Push) {
            $currentBranch = (& git -C $ProjectPath rev-parse --abbrev-ref HEAD).Trim()
            if ($currentBranch -and $currentBranch -ne "HEAD") {
                Write-Host "Отправка изменений в origin/$currentBranch..." -ForegroundColor Cyan
                & git -C $ProjectPath push origin $currentBranch
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
        $logEntry = "`n- **Чекпоинт [$timestamp]**: $Message"
        if ($stateContent -match "(## 5\. История Изменений[^\r\n]*)") {
            $stateContent = $stateContent -replace "(## 5\. История Изменений[^\r\n]*)", "`$1`n$logEntry"
            [System.IO.File]::WriteAllText($stateFile, $stateContent, [System.Text.Encoding]::UTF8)
            Write-Host "[OK] Запись добавлена в PROJECT_STATE.md" -ForegroundColor Green
        }
    } catch {
        Write-Warning "Не удалось обновить PROJECT_STATE.md: $_"
    }
}

Write-Host "`nЧекпоинт завершен успешно!" -ForegroundColor Green
