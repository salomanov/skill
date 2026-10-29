param(
    [int]$KeepCount = 10,
    [int]$MaxAgeDays = 30,
    [switch]$DryRun = $false,
    [string]$ProjectPath = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

Write-Host "`n=== [Project Guardian] Ротация и Очистка Промежуточных Бэкапов ===" -ForegroundColor Cyan
Write-Host "Проект: $ProjectPath"
Write-Host "Политика: Хранить последние $KeepCount промежуточных чекпоинтов, удалять старше $MaxAgeDays дней."
if ($DryRun) {
    Write-Host "[РЕЖИМ ТЕСТА (DryRun)]: Реальное удаление файлов отключено.`n" -ForegroundColor Yellow
}

$backupRoot = Join-Path $ProjectPath ".backups"
if (-not (Test-Path $backupRoot)) {
    Write-Host "Папка .backups отсутствует. Нечего очищать." -ForegroundColor Gray
    return
}

$allDirs = Get-ChildItem -Path $backupRoot -Directory

# 1. Защита несгораемых релизов
$immutableReleases = $allDirs | Where-Object { 
    $_.Name -like "firmware_success_*" -or 
    $_.Name -like "desktop_release_*" -or 
    $_.Name -like "web_release_*" 
}
Write-Host "Несгораемые релизные архивы (НИКОГДА не удаляются): $($immutableReleases.Count)" -ForegroundColor Green
foreach ($rel in $immutableReleases) {
    Write-Host "  🔒 $($rel.Name) ($($rel.CreationTime.ToString('yyyy-MM-dd HH:mm')))" -ForegroundColor Gray
}

# 2. Поиск промежуточных чекпоинтов кода
$checkpoints = $allDirs | Where-Object { 
    $_.Name -like "checkpoint*" 
} | Sort-Object CreationTime -Descending

Write-Host "`nВсего найдено промежуточных чекпоинтов кода: $($checkpoints.Count)" -ForegroundColor Cyan

if ($checkpoints.Count -le $KeepCount) {
    Write-Host "Количество чекпоинтов ($($checkpoints.Count)) не превышает лимит ($KeepCount). Очистка не требуется." -ForegroundColor Green
    return
}

# Чекпоинты к удалению (те, что идут после $KeepCount)
$toDelete = $checkpoints | Select-Object -Skip $KeepCount

$cutoffDate = (Get-Date).AddDays(-$MaxAgeDays)
$candidateFolders = $toDelete | Where-Object { $_.CreationTime -lt $cutoffDate -or $checkpoints.Count -gt ($KeepCount * 2) }

if ($candidateFolders.Count -eq 0) {
    # Если старых по дням нет, но превышение большое — удаляем самые старые сверх лимита
    $candidateFolders = $toDelete
}

$totalFreedBytes = 0
Write-Host "`nКандидаты на удаление ($($candidateFolders.Count) папок):" -ForegroundColor Yellow

foreach ($dir in $candidateFolders) {
    $dirSize = (Get-ChildItem -Path $dir.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    $sizeMB = [math]::Round($dirSize / 1MB, 2)
    $totalFreedBytes += $dirSize

    if ($DryRun) {
        Write-Host "  [DryRun] Будет удален: $($dir.Name) ($sizeMB MB, создан $($dir.CreationTime.ToString('yyyy-MM-dd')))" -ForegroundColor Yellow
    } else {
        try {
            Remove-Item -Path $dir.FullName -Recurse -Force
            Write-Host "  [УДАЛЕН]: $($dir.Name) (освобождено $sizeMB MB)" -ForegroundColor Red
        } catch {
            Write-Warning "Не удалось удалить $($dir.Name): $_"
        }
    }
}

$totalFreedMB = [math]::Round($totalFreedBytes / 1MB, 2)
Write-Host "`n" + ("=" * 60)
if ($DryRun) {
    Write-Host "ИТОГ (DryRun): Можно освободить: $totalFreedMB MB дискового пространства." -ForegroundColor Green
    Write-Host "Для реального удаления запустите без флага -DryRun." -ForegroundColor Gray
} else {
    Write-Host "ИТОГ: Успешно освобождено: $totalFreedMB MB дискового пространства!" -ForegroundColor Green
}
Write-Host ""
