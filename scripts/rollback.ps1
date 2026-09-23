param(
    [string]$ProjectPath = (Get-Location).Path,
    [string]$TargetCheckpoint = ""
)

$ErrorActionPreference = "Stop"

Write-Host "=== [Project Guardian] Запуск отката (Rollback) ===" -ForegroundColor Yellow
Write-Host "Проект: $ProjectPath"

$backupRoot = Join-Path $ProjectPath ".backups"

# 1. Поиск контрольных точек
if (-not (Test-Path $backupRoot)) {
    Write-Error "Папка .backups не найдена в $ProjectPath. Нет доступных локальных точек отката."
    return
}

$checkpoints = Get-ChildItem -Path $backupRoot -Directory | Where-Object { $_.Name -like "checkpoint_*" } | Sort-Object CreationTime -Descending

if ($checkpoints.Count -eq 0) {
    Write-Error "В папке .backups нет сохраненных чекпоинтов."
    return
}

$selectedCheckpoint = $null
if ($TargetCheckpoint -ne "") {
    $selectedCheckpoint = $checkpoints | Where-Object { $_.Name -eq $TargetCheckpoint } | Select-Object -First 1
    if (-not $selectedCheckpoint) {
        Write-Error "Чекпоинт '$TargetCheckpoint' не найден среди доступных."
        return
    }
} else {
    $selectedCheckpoint = $checkpoints[0]
}

Write-Host "Выбран чекпоинт для восстановления: $($selectedCheckpoint.Name)" -ForegroundColor Cyan
Write-Host "Дата создания чекпоинта: $($selectedCheckpoint.CreationTime)"

# 2. Восстановление файлов
$excludeDirs = @(".git", ".backups", "node_modules", ".venv", "venv")

try {
    $backupItems = Get-ChildItem -Path $selectedCheckpoint.FullName -Force
    foreach ($item in $backupItems) {
        if ($excludeDirs -contains $item.Name) { continue }
        $destination = Join-Path $ProjectPath $item.Name
        Copy-Item -Path $item.FullName -Destination $destination -Recurse -Force
    }
    Write-Host "[OK] Файлы проекта успешно восстановлены из: $($selectedCheckpoint.Name)" -ForegroundColor Green
}
catch {
    Write-Error "Ошибка при копировании файлов из бэкапа: $_"
}

# 3. Если Git активен, сбрасываем незакоммиченные хвосты если нужно
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
