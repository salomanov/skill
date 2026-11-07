<#
.SYNOPSIS
    Безопасный генератор шаблонов scratch-скриптов для отладки и тестов.
.DESCRIPTION
    Создает изолированный скрипт в папке scratch/ с гарантированной кодировкой UTF-8
    и защитой от сбоев Windows CP1251. При передаче флага -WithSSH автоматически
    считывает существующие параметры подключения из deploy.py, .env или config.json.
.PARAMETER Name
    Имя создаваемого скрипта (без расширения или с ним).
.PARAMETER Type
    Тип скрипта: Python (по умолчанию) или PowerShell.
.PARAMETER WithSSH
    Включить готовый блок подключения Paramiko SSH с авто-подстановкой кредов.
.PARAMETER ProjectPath
    Целевой проект (по умолчанию текущая директория).
.PARAMETER Force
    Перезаписать существующий файл в scratch/.
.EXAMPLE
    & "scripts/new-scratch.ps1" -Name "check_dns" -WithSSH
    & "scripts/new-scratch.ps1" -Name "quick_test" -Type PowerShell
#>

param(
    [Parameter(Position=0, Mandatory=$true)]
    [string]$Name,

    [ValidateSet("Python", "PowerShell", "Py", "PS1")]
    [string]$Type = "Python",

    [switch]$WithSSH = $false,
    [string]$ProjectPath = (Get-Location).Path,
    [switch]$Force = $false
)

$ErrorActionPreference = "Stop"
$env:PYTHONIOENCODING = "utf-8"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# 0. Нормализация пути
if ($ProjectPath -and (Test-Path $ProjectPath)) {
    $ProjectPath = (Resolve-Path $ProjectPath).Path
}

$scratchDir = Join-Path $ProjectPath "scratch"
if (-not (Test-Path $scratchDir)) {
    New-Item -ItemType Directory -Path $scratchDir -Force | Out-Null
}

# 1. Определение расширения и имени файла
$ext = if ($Type -match "PS1|PowerShell") { ".ps1" } else { ".py" }
$cleanName = $Name -replace '(\.py|\.ps1)$', ''
$cleanName = $cleanName -replace '[^\w\-]', '_'
$targetFile = Join-Path $scratchDir "$cleanName$ext"

if ((Test-Path $targetFile) -and (-not $Force)) {
    Write-Warning "Файл уже существует: $targetFile (используйте -Force для перезаписи)"
    return
}

# 2. Генерация Python-скрипта
if ($ext -eq ".py") {
    $sshBlock = ""
    if ($WithSSH) {
        # Попытка считать реальные креды из проекта
        $detectedHost = "192.168.1.1"
        $detectedPort = 222
        $detectedUser = "root"
        $detectedPass = ""

        # Сканируем deploy.py, config*.py, .env
        $credFiles = Get-ChildItem -Path $ProjectPath -Recurse -File -Include "deploy.py", "*.env", "*config*.json", "settings.py" -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notlike "*\.backups\*" -and $_.FullName -notlike "*\.git\*" }

        foreach ($cf in $credFiles) {
            $txt = Get-Content -LiteralPath $cf.FullName -Raw -ErrorAction SilentlyContinue
            if ($txt) {
                if ($txt -match '(?i)(?:host|ROUTER_HOST|HOST)\s*=\s*["'']([^"'']+)["'']') { $detectedHost = $matches[1] }
                if ($txt -match '(?i)(?:port|ROUTER_PORT|PORT)\s*=\s*(\d+)') { $detectedPort = [int]$matches[1] }
                if ($txt -match '(?i)(?:user|ROUTER_USER|USER|username)\s*=\s*["'']([^"'']+)["'']') { $detectedUser = $matches[1] }
                if ($txt -match '(?i)(?:pass|password|SSH_PASS|passwd)\s*=\s*["'']([^"'']+)["'']') { $detectedPass = $matches[1] }
            }
            if ($detectedPass) { break }
        }

        $passLiteral = if ($detectedPass) { "`"$detectedPass`"" } else { "`"`"  # ВНИМАНИЕ: укажите пароль из deploy.py или .env" }

        $sshBlock = @"

# --- Автоматически считанные параметры подключения SSH ---
SSH_HOST = "$detectedHost"
SSH_PORT = $detectedPort
SSH_USER = "$detectedUser"
SSH_PASS = $passLiteral

import paramiko

def get_ssh_client():
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    if not SSH_PASS:
        raise ValueError("Пароль SSH не задан! Считайте его из deploy.py или .env")
    client.connect(SSH_HOST, port=SSH_PORT, username=SSH_USER, password=SSH_PASS, timeout=10)
    return client
"@
    }

    $pyContent = @"
import sys
import os

# 1. Защита от краха Windows CP1251 UnicodeEncodeError (эмодзи, псевдографика)
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')
$sshBlock

def main():
    print(f"=== Запуск scratch-скрипта: $cleanName ===")
"@

    if ($WithSSH) {
        $pyContent += @"

    try:
        with get_ssh_client() as ssh:
            print(f"[OK] Подключено к {SSH_HOST}:{SSH_PORT} ({SSH_USER})")
            
            # Пример выполнения команды:
            cmd = "uptime"
            print(f">>> {cmd}")
            stdin, stdout, stderr = ssh.exec_command(cmd)
            out = stdout.read().decode('utf-8', errors='ignore')
            err = stderr.read().decode('utf-8', errors='ignore')
            if out:
                print(out.strip())
            if err:
                print("STDERR:", err.strip())
    except Exception as e:
        print(f"[ERROR] Ошибка SSH-соединения: {e}")
        sys.exit(1)
"@
    } else {
        $pyContent += @"

    try:
        # TODO: Ваш рабочий код проверки здесь
        print("[OK] Скрипт готов к работе.")
    except Exception as e:
        print(f"[ERROR] Ошибка выполнения: {e}")
        sys.exit(1)
"@
    }

    $pyContent += @"


if __name__ == "__main__":
    main()
"@

    # Сохраняем строго в UTF-8
    [System.IO.File]::WriteAllText($targetFile, $pyContent, [System.Text.Encoding]::UTF8)
} else {
    # 3. Генерация PowerShell-скрипта
    $psContent = @"
<#
.SYNOPSIS
    Безопасный scratch-скрипт PowerShell.
#>

param()

`$ErrorActionPreference = "Stop"
`$env:PYTHONIOENCODING = "utf-8"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
`$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "=== Запуск scratch-скрипта: $cleanName ===" -ForegroundColor Cyan

try {
    # TODO: Ваш код проверки здесь
    Write-Host "[OK] Выполнено успешно." -ForegroundColor Green
}
catch {
    Write-Error "Ошибка: `$_"
    exit 1
}
"@

    # Для PowerShell обязательно сохраняем с UTF-8 BOM
    [System.IO.File]::WriteAllText($targetFile, $psContent, [System.Text.Encoding]::UTF8)
}

Write-Host "[OK] Создан безопасный scratch-скрипт: $targetFile" -ForegroundColor Green
$runCmd = if ($ext -eq '.py') { "python `"$targetFile`"" } else { "& `"$targetFile`"" }
Write-Host "     Запуск: $runCmd" -ForegroundColor Gray
