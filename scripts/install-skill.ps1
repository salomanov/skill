param(
    [Parameter(Mandatory=$true)]
    [string]$SkillName,
    [string]$DestDir = (Join-Path $HOME ".gemini\config\skills"),
    [switch]$Update,
    [switch]$CheckOnly,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$env:PYTHONIOENCODING = "utf-8"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "=== [Project Guardian] Управление скиллом '$SkillName' ===" -ForegroundColor Cyan
Write-Host "Источник: github.com/sickn33/agentic-awesome-skills"

$targetSkillDir = Join-Path $DestDir $SkillName
$targetSkillFile = Join-Path $targetSkillDir "SKILL.md"
$existsLocally = (Test-Path -LiteralPath $targetSkillFile -PathType Leaf)

if ($existsLocally -and -not $Update -and -not $CheckOnly -and -not $Force) {
    Write-Host "[Инфо] Скилл '$SkillName' уже установлен локально: $targetSkillDir" -ForegroundColor Yellow
    Write-Host "Для проверки обновлений используйте: -CheckOnly или -Update" -ForegroundColor Gray
    exit 0
}

function Download-GitHubDirectory {
    param (
        [string]$RepoPath,
        [string]$LocalPath
    )

    if (-not (Test-Path -LiteralPath $LocalPath)) {
        New-Item -ItemType Directory -Path $LocalPath -Force | Out-Null
    }

    $apiUrl = "https://api.github.com/repos/sickn33/agentic-awesome-skills/contents/$RepoPath"
    $headers = @{ "User-Agent" = "ProjectGuardian-SkillInstaller" }
    $ghToken = if ($env:GITHUB_TOKEN) { $env:GITHUB_TOKEN } elseif ($env:GH_TOKEN) { $env:GH_TOKEN } else { $null }
    if ($ghToken) {
        $headers["Authorization"] = "Bearer $ghToken"
    }

    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 15
        foreach ($item in $response) {
            $destFile = Join-Path $LocalPath $item.name
            if ($item.type -eq "file") {
                Write-Host "  Скачивание: $($item.path)..." -ForegroundColor Gray
                Invoke-WebRequest -Uri $item.download_url -OutFile $destFile -UseBasicParsing -TimeoutSec 20 | Out-Null
            } elseif ($item.type -eq "dir") {
                Download-GitHubDirectory -RepoPath $item.path -LocalPath $destFile
            }
        }
        return $true
    } catch {
        return $false
    }
}

# Если запрошена только проверка обновлений
if ($CheckOnly) {
    Write-Host "Проверка актуальности скилла '$SkillName' в апстриме..." -ForegroundColor Cyan
    try {
        $rawUrl = "https://raw.githubusercontent.com/sickn33/agentic-awesome-skills/main/skills/$SkillName/SKILL.md"
        $upstreamContent = (Invoke-WebRequest -Uri $rawUrl -UseBasicParsing -TimeoutSec 15).Content
        if ($existsLocally) {
            $localContent = [System.IO.File]::ReadAllText($targetSkillFile, [System.Text.Encoding]::UTF8)
            if ($upstreamContent.Trim() -eq $localContent.Trim()) {
                Write-Host "[OK] Скилл '$SkillName' актуален (полное совпадение с upstream)." -ForegroundColor Green
            } else {
                Write-Host "⚡ Доступно обновление для скилла '$SkillName'!" -ForegroundColor Yellow
                Write-Host "Для обновления запустите: install-skill.ps1 -SkillName '$SkillName' -Update" -ForegroundColor Cyan
            }
        } else {
            Write-Host "Скилл '$SkillName' найден в каталоге, но ещё не установлен локально." -ForegroundColor Gray
        }
    } catch {
        Write-Warning "Не удалось связаться с репозиторием sickn33/agentic-awesome-skills: $_"
    }
    exit 0
}

# Установка или обновление
$installed = $false
Write-Host "Загрузка актуальной версии скилла '$SkillName'..." -ForegroundColor Cyan

# 1. Попытка рекурсивной загрузки через GitHub API
$apiSuccess = Download-GitHubDirectory -RepoPath "skills/$SkillName" -LocalPath $targetSkillDir

if ($apiSuccess -and (Test-Path -LiteralPath (Join-Path $targetSkillDir "SKILL.md") -PathType Leaf)) {
    $installed = $true
} else {
    # 2. Фолбэк: скачивание SKILL.md напрямую через raw.githubusercontent.com
    Write-Host "Фолбэк: прямое скачивание через raw.githubusercontent.com..." -ForegroundColor Yellow
    try {
        if (-not (Test-Path -LiteralPath $targetSkillDir)) {
            New-Item -ItemType Directory -Path $targetSkillDir -Force | Out-Null
        }
        $rawUrl = "https://raw.githubusercontent.com/sickn33/agentic-awesome-skills/main/skills/$SkillName/SKILL.md"
        Invoke-WebRequest -Uri $rawUrl -OutFile $targetSkillFile -UseBasicParsing -TimeoutSec 20 | Out-Null
        if (Test-Path -LiteralPath $targetSkillFile -PathType Leaf) {
            $installed = $true
            Write-Host "  [Инфо]: Установлена/обновлена базовая версия скилла (SKILL.md)." -ForegroundColor Gray
        }
    } catch {
        Write-Warning "Не удалось загрузить скилл '$SkillName': $_"
    }
}

if ($installed) {
    $actionVerb = if ($existsLocally -and $Update) { "обновлён" } else { "установлен" }
    Write-Host "[OK] Скилл '$SkillName' успешно $actionVerb в: $targetSkillDir" -ForegroundColor Green

    # Обновление .antigravity-install-manifest.json
    $manifestPath = Join-Path $DestDir ".antigravity-install-manifest.json"
    if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
        try {
            $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($manifest.entries -notcontains $SkillName) {
                $manifest.entries += $SkillName
            }
            $manifest.updatedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            $manifestJson = $manifest | ConvertTo-Json -Depth 5
            [System.IO.File]::WriteAllText($manifestPath, $manifestJson, [System.Text.Encoding]::UTF8)
            Write-Host "[OK] Запись обновлена в манифесте скиллов" -ForegroundColor Green
        } catch {
            Write-Warning "Не удалось обновить файл манифеста: $_"
        }
    }
} else {
    Write-Error "Не удалось установить или обновить скилл '$SkillName'. Проверьте точное название в каталоге sickn33/agentic-awesome-skills."
}
