param(
    [string]$ProjectPath = (Get-Location).Path,
    [string]$TargetCheckpoint = ""
)

$ErrorActionPreference = "Stop"

Write-Host "=== [Project Guardian] Запуск отката (Rollback) ===" -ForegroundColor Yellow
Write-Host "Проект: $ProjectPath"

$backupRoot = Join-Path $ProjectPath ".backups"

# 1. Поиск контрольных точек и бэкапов прошивок
if (-not (Test-Path $backupRoot)) {
    Write-Error "Папка .backups не найдена в $ProjectPath. Нет доступных локальных точек отката."
    return
}

$checkpoints = Get-ChildItem -Path $backupRoot -Directory | Where-Object { 
    $_.Name -like "checkpoint_*" -or $_.Name -like "firmware_success_*" 
} | Sort-Object CreationTime -Descending

if ($checkpoints.Count -eq 0) {
    Write-Error "В папке .backups нет сохраненных чекпоинтов или бэкапов прошивки."
    return
}

$selectedCheckpoint = $null
if ($TargetCheckpoint -ne "") {
    $selectedCheckpoint = $checkpoints | Where-Object { $_.Name -eq $TargetCheckpoint } | Select-Object -First 1
    if (-not $selectedCheckpoint) {
        Write-Error "Точка отката '$TargetCheckpoint' не найдена среди доступных."
        return
    }
} else {
    $selectedCheckpoint = $checkpoints[0]
}

Write-Host "Выбрана точка для восстановления: $($selectedCheckpoint.Name)" -ForegroundColor Cyan
Write-Host "Дата создания: $($selectedCheckpoint.CreationTime)"

# 2. Восстановление файлов
$excludeDirs = @(".git", ".backups", "node_modules", ".venv", "venv", "firmware_binaries")

try {
    $backupItems = Get-ChildItem -Path $selectedCheckpoint.FullName -Force
    foreach ($item in $backupItems) {
        if ($excludeDirs -contains $item.Name) { continue }
        $destination = Join-Path $ProjectPath $item.Name
        Copy-Item -Path $item.FullName -Destination $destination -Recurse -Force
    }
    Write-Host "[OK] Файлы проекта успешно восстановлены из: $($selectedCheckpoint.Name)" -ForegroundColor Green

    # Если восстанавливаем прошивку и есть сохраненные бинарники, сообщаем о них
    $binDir = Join-Path $selectedCheckpoint.FullName "firmware_binaries"
    if (Test-Path $binDir) {
        Write-Host "Внимание: бинарники прошивки сохранены в: $binDir" -ForegroundColor Magenta
    }
}
catch {
    Write-Error "Ошибка при копировании файлов из бэкапа: $_"
}

# 3. Если Git активен, выводим статус
try {
    $gitCheck = & git -C $ProjectPath rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -eq 0 -and $gitCheck.Trim() -eq "true") {
        Write-Host "Статус Git после отката:" -ForegroundColor Cyan
        & git -C $ProjectPath status --short
    }
} catch {
    # Git опционален
}

Write-Host "`nОткат успешно завершен!" -ForegroundColor Green
