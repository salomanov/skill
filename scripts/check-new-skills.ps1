param(
    [int]$ReleasesCount = 4,
    [string]$Filter = "",
    [string]$SkillsDir = (Join-Path $HOME ".gemini\config\skills"),
    [switch]$OnlyUninstalled
)

$ErrorActionPreference = "Stop"
$env:PYTHONIOENCODING = "utf-8"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "=== [Project Guardian] Мониторинг новых скиллов в каталоге ===" -ForegroundColor Cyan
Write-Host "Источник: sickn33/agentic-awesome-skills"

$changelogUrl = "https://raw.githubusercontent.com/sickn33/agentic-awesome-skills/main/CHANGELOG.md"

try {
    $content = (Invoke-WebRequest -Uri $changelogUrl -UseBasicParsing -TimeoutSec 15).Content
} catch {
    Write-Error "Не удалось загрузить CHANGELOG.md из GitHub: $_"
    exit 1
}

# Разбивка по заголовкам релизов: ## [X.Y.Z] - YYYY-MM-DD
$lines = $content -split "`r?`n"
$releases = @()
$currentRelease = $null
$inNewSkills = $false

foreach ($line in $lines) {
    if ($line -match '^##\s+\[([\d\.]+)\]\s*-\s*([\d-]+)(?:\s*-\s*"([^"]+)")?') {
        $ver = $matches[1]
        $date = $matches[2]
        $title = if ($matches[3]) { $matches[3] } else { "" }
        $currentRelease = [PSCustomObject]@{
            Version = $ver
            Date = $date
            Title = $title
            NewSkills = @()
        }
        $releases += $currentRelease
        $inNewSkills = $false
        continue
    }

    if ($line -match '^###\s+New skills') {
        $inNewSkills = $true
        continue
    }

    if ($line -match '^###\s+' -and -not ($line -match '^###\s+New skills')) {
        $inNewSkills = $false
        continue
    }

    if ($inNewSkills -and $currentRelease -and $line -match '^\s*-\s+(.+)') {
        $skillDesc = $matches[1]
        $currentRelease.NewSkills += $skillDesc
    }
}

$selectedReleases = $releases | Select-Object -First $ReleasesCount

Write-Host "`nНайдено последних релизов: $($selectedReleases.Count)`n" -ForegroundColor Gray

foreach ($rel in $selectedReleases) {
    Write-Host "────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "📦 Релиз [$($rel.Version)] от $($rel.Date) — `"$($rel.Title)`"" -ForegroundColor Yellow
    if ($rel.NewSkills.Count -eq 0) {
        Write-Host "  (В этом релизе только улучшения существующих скиллов и ядра)" -ForegroundColor DarkGray
        continue
    }

    foreach ($item in $rel.NewSkills) {
        # Извлечение имени скилла (обычно в обратных кавычках `skill-name`)
        $skillName = ""
        if ($item -match '`([^`]+)`') {
            $skillName = $matches[1]
        }

        # Фильтрация по ключевому слову
        if ($Filter -and -not ($item -match $Filter) -and -not ($skillName -match $Filter)) {
            continue
        }

        $isInstalled = $false
        if ($skillName) {
            $targetPath = Join-Path $SkillsDir $skillName
            $isInstalled = (Test-Path -LiteralPath (Join-Path $targetPath "SKILL.md") -PathType Leaf)
        }

        if ($OnlyUninstalled -and $isInstalled) {
            continue
        }

        $statusBadge = if ($isInstalled) { "[УСТАНОВЛЕН]" } else { "[НОВЫЙ / ДОСТУПЕН]" }
        $statusColor = if ($isInstalled) { "Green" } else { "Cyan" }

        Write-Host "  • " -NoNewline -ForegroundColor White
        Write-Host "$statusBadge " -NoNewline -ForegroundColor $statusColor
        Write-Host $item -ForegroundColor White
        if (-not $isInstalled -and $skillName) {
            Write-Host "    └─ Установить: install-skill.ps1 -SkillName `"$skillName`"" -ForegroundColor Gray
        }
    }
}

Write-Host "`n────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "Для установки любого скилла выполните: install-skill.ps1 -SkillName <имя>" -ForegroundColor Gray
