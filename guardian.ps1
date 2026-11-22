<#
.SYNOPSIS
    Project Guardian v2.2 - шим CLI-фасада.
.DESCRIPTION
    Единственный источник правды - scripts/guardian.ps1. Эта копия в корне нужна только
    для удобного запуска из корня репозитория (.\guardian.ps1 <команда>).

    Почему шим, а не копия: в v2.0-v2.1 в корне и в scripts/ лежали два байт-в-байт
    одинаковых файла по 137 строк, которые правились вручную и могли разойтись
    (дрейф обнаруживался только сравнением хешей).
#>

$target = Join-Path $PSScriptRoot 'scripts\guardian.ps1'
if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
    Write-Host "[ERROR] Не найден scripts/guardian.ps1 рядом с '$PSScriptRoot'." -ForegroundColor Red
    exit 1
}

& $target @args
exit $LASTEXITCODE
