<#
.SYNOPSIS
    Универсальная отправка email для Project Guardian.
.DESCRIPTION
    Отправляет письмо через SMTP с вложениями, используя глобальные настройки из
    ~/.gemini/config/email_settings.json. Автоматически выбирает получателя по умолчанию (salomanov@ya.ru).
.PARAMETER Subject
    Тема письма.
.PARAMETER Body
    Текст сообщения (поддерживает многострочный текст и HTML).
.PARAMETER To
    Адрес получателя (по умолчанию из email_settings.json).
.PARAMETER Attachments
    Один или несколько путей к файлам для прикрепления к письму.
.PARAMETER Html
    Флаг: отправлять как HTML.
.EXAMPLE
    & "C:\Users\Salomanov\.gemini\config\skills\project-guardian\scripts\send-email.ps1" -Subject "Отчет" -Body "Все готово!" -Attachments "build/app.zip"
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Subject,

    [Parameter(Mandatory=$true, Position=1)]
    [string]$Body,

    [Parameter(Mandatory=$false)]
    [string]$To = "",

    [Parameter(Mandatory=$false)]
    [string[]]$Attachments = @(),

    [Parameter(Mandatory=$false)]
    [switch]$Html
)

$ErrorActionPreference = "Stop"
$env:PYTHONIOENCODING = "utf-8"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$pyScript = Join-Path $PSScriptRoot "send-email.py"
if (-not (Test-Path -LiteralPath $pyScript)) {
    Write-Error "Скрипт $pyScript не найден!"
    exit 1
}

$argsList = @(
    $pyScript,
    "--subject", $Subject,
    "--body", $Body
)

if ($To) {
    $argsList += @("--to", $To)
}

if ($Html) {
    $argsList += "--html"
}

if ($Attachments -and $Attachments.Count -gt 0) {
    $argsList += "--attach"
    foreach ($att in $Attachments) {
        if ($att) {
            $argsList += $att
        }
    }
}

& python $argsList
if ($LASTEXITCODE -ne 0) {
    Write-Error "Ошибка при отправке email (exit code: $LASTEXITCODE)"
    exit $LASTEXITCODE
}
