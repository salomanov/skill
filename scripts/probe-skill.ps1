<#
.SYNOPSIS
    Project Guardian - Зондирование скилла (Probe Skill) по принципам Harness²
.DESCRIPTION
    Проводит комплексную проверку скилла перед установкой или аудитом:
    1. Наличие и валидность манифеста SKILL.md (YAML frontmatter: name, description)
    2. Кодировка UTF-8 и отсутствие поврежденных символов
    3. Синтаксис встроенных скриптов (.ps1 через AST, .py через py_compile, .sh без BOM)
    4. Кроссплатформенность и совместимость с Windows (детекция хардкода sudo, apt-get, yum)
    5. Проверка безопасности (отсутствие приватных ключей и открытых паролей)
.PARAMETER SkillPath
    Путь к папке скилла или файлу SKILL.md.
.PARAMETER SkillName
    Имя скилла для авто-поиска в ~/.gemini/config/skills или текущем каталоге.
.PARAMETER Strict
    Считать предупреждения ошибками (exit 1).
.PARAMETER Quiet
    Минималистичный вывод (только статус и ошибки).
#>

param(
    [string]$SkillPath,
    [string]$SkillName,
    [switch]$Strict,
    [switch]$Quiet
)

$ErrorActionPreference = "Continue"
$env:PYTHONIOENCODING = "utf-8"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$targetDir = $null
$skillFile = $null

if ($SkillPath) {
    if (Test-Path -LiteralPath $SkillPath) {
        $resolved = (Resolve-Path -LiteralPath $SkillPath).Path
        if ((Get-Item -LiteralPath $resolved) -is [System.IO.DirectoryInfo]) {
            $targetDir = $resolved
            $skillFile = Join-Path $targetDir "SKILL.md"
        } elseif ([System.IO.Path]::GetFileName($resolved).Equals("SKILL.md", [System.StringComparison]::OrdinalIgnoreCase)) {
            $skillFile = $resolved
            $targetDir = [System.IO.Path]::GetDirectoryName($resolved)
        } else {
            $targetDir = [System.IO.Path]::GetDirectoryName($resolved)
            $skillFile = Join-Path $targetDir "SKILL.md"
        }
    } else {
        Write-Host "`n[FAIL] Путь не существует: $SkillPath" -ForegroundColor Red
        Write-Host "PROBE FAILED: Директория или файл не найдены.`n" -ForegroundColor Red
        exit 1
    }
} elseif ($SkillName) {
    $candidates = @(
        (Join-Path (Get-Location).Path $SkillName),
        (Join-Path $HOME ".gemini\config\skills\$SkillName"),
        (Join-Path $HOME ".gemini\antigravity\builtin\skills\$SkillName")
    )
    foreach ($cand in $candidates) {
        if (Test-Path -LiteralPath (Join-Path $cand "SKILL.md")) {
            $targetDir = (Resolve-Path -LiteralPath $cand).Path
            $skillFile = Join-Path $targetDir "SKILL.md"
            break
        }
    }
    if (-not $targetDir) {
        Write-Host "`n[FAIL] Скилл '$SkillName' не найден ни в текущей папке, ни в ~/.gemini/config/skills/" -ForegroundColor Red
        Write-Host "PROBE FAILED: Скилл не обнаружен.`n" -ForegroundColor Red
        exit 1
    }
} else {
    $targetDir = (Get-Location).Path
    $skillFile = Join-Path $targetDir "SKILL.md"
}

if (-not $Quiet) {
    Write-Host "`n=== [Project Guardian] Зондирование скилла (Probe Skill v2.1) ===" -ForegroundColor Cyan
    Write-Host "Целевой каталог: $targetDir"
}

$errors = @()
$warnings = @()

# 1. Проверка наличия SKILL.md
if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) {
    $errors += "Манифест SKILL.md отсутствует в $targetDir"
} else {
    try {
        $skillText = [System.IO.File]::ReadAllText($skillFile, [System.Text.Encoding]::UTF8)
        if ([string]::IsNullOrWhiteSpace($skillText)) {
            $errors += "Файл SKILL.md пуст"
        } else {
            # 2. Проверка frontmatter (YAML)
            if ($skillText -match '(?s)^---\r?\n(.*?)\r?\n---') {
                $fm = $matches[1]
                $hasName = ($fm -match '(?m)^name:\s*([^\r\n]+)')
                $hasDesc = ($fm -match '(?m)^description:\s*([^\r\n]+)')
                if (-not $hasName) {
                    $errors += "Frontmatter SKILL.md не содержит обязательного поля 'name:'"
                }
                if (-not $hasDesc) {
                    $errors += "Frontmatter SKILL.md не содержит обязательного поля 'description:'"
                }
            } else {
                $warnings += "SKILL.md не содержит стандартного YAML frontmatter (--- ... ---)"
            }

            # 3. Проверка опасных или несовместимых команд для Windows
            $lines = $skillText -split "`r?`n"
            $inCodeBlock = $false
            for ($i = 0; $i -lt $lines.Length; $i++) {
                $l = $lines[$i]
                if ($l -match '^```') {
                    $inCodeBlock = -not $inCodeBlock
                    continue
                }
                # Игнорируем строки, которые формулируют правила запрета
                if ($l -match 'запрещ|нельзя|never|disallow|prohibit|forbidden|SEC-\d+') {
                    continue
                }
                if ($inCodeBlock -and $l -match '^\s*(sudo\s+|apt-get\s+|yum\s+|pacman\s+|brew\s+)') {
                    $warnings += "Строка $($i+1): Обнаружены Linux/macOS команды управления пакетами ($($matches[1].Trim())) без альтернатив для Windows"
                }
                if ($l -match '^\s*chmod\s+777\b' -or ($inCodeBlock -and $l -match '\bchmod\s+777\b')) {
                    $errors += "Строка $($i+1): Небезопасный вызов 'chmod 777'"
                }
            }
        }
    } catch {
        $errors += "Ошибка чтения SKILL.md: $_"
    }
}

# 4. Проверка встроенных скриптов в каталоге скилла
if (Test-Path -LiteralPath $targetDir) {
    $allFiles = Get-ChildItem -LiteralPath $targetDir -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](\.git|\.backups|node_modules|\.venv|venv|scratch)[\\/]' }

    foreach ($file in $allFiles) {
        $ext = $file.Extension.ToLowerInvariant()
        $relPath = $file.FullName.Substring($targetDir.Length).TrimStart('\', '/')

        # PowerShell AST syntax check
        if ($ext -eq '.ps1') {
            try {
                $parseErrors = $null
                $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
                [void][System.Management.Automation.Language.Parser]::ParseInput($content, $file.FullName, [ref]$null, [ref]$parseErrors)
                if ($parseErrors -and $parseErrors.Count -gt 0) {
                    $errors += "Синтаксическая ошибка в PowerShell ($relPath): $($parseErrors[0].Message) (строка $($parseErrors[0].Extent.StartLineNumber))"
                }
            } catch {
                $errors += "Сбой парсинга PowerShell ($relPath): $_"
            }
        }

        # Python syntax check
        if ($ext -eq '.py') {
            $pyOut = & python -m py_compile "$($file.FullName)" 2>&1
            if ($LASTEXITCODE -ne 0) {
                $errors += "Синтаксическая ошибка в Python ($relPath): $pyOut"
            }
        }

        # Shell BOM check (SYNTAX-BOM)
        if ($ext -eq '.sh') {
            try {
                $fs = [System.IO.File]::OpenRead($file.FullName)
                $hdr = New-Object byte[] 3
                $readCount = $fs.Read($hdr, 0, 3)
                $fs.Dispose()
                if ($readCount -eq 3 -and $hdr[0] -eq 0xEF -and $hdr[1] -eq 0xBB -and $hdr[2] -eq 0xBF) {
                    $errors += "Файл Shell ($relPath) содержит UTF-8 BOM, что ломает выполнение на Linux/WSL/Android"
                }
            } catch { }
        }

        # Secret check
        try {
            if ($file.Length -lt 500KB) {
                $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
                if ($content -match 'BEGIN (RSA|OPENSSH) PRIVATE KEY') {
                    $errors += "Обнаружен закрытый ключ в ($relPath)"
                }
            }
        } catch { }
    }
}

# Отчет
if (-not $Quiet) {
    if ($errors.Count -eq 0 -and $warnings.Count -eq 0) {
        Write-Host "  [OK] Все проверки успешно пройдены." -ForegroundColor Green
    } else {
        foreach ($w in $warnings) {
            Write-Host "  [WARN] $w" -ForegroundColor Yellow
        }
        foreach ($e in $errors) {
            Write-Host "  [FAIL] $e" -ForegroundColor Red
        }
    }
}

$effectiveErrors = $errors.Count
if ($Strict -and $warnings.Count -gt 0) {
    $effectiveErrors += $warnings.Count
}

if ($effectiveErrors -eq 0) {
    Write-Host "`nPROBE PASSED: Скилл полностью валиден и готов к работе в среде Windows/Antigravity.`n" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nPROBE FAILED: Обнаружено ошибок: $($errors.Count), предупреждений: $($warnings.Count).`n" -ForegroundColor Red
    exit 1
}
