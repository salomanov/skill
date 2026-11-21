<#
.SYNOPSIS
    Универсальный и безопасный раннер тестов Project Guardian с Auto-Ensure для pytest/unittest.
.DESCRIPTION
    Исключает exit code 1 из-за отсутствия раннера. Проверяет наличие pytest;
    если отсутствует — автоматически устанавливает через uv или pip, либо чисто
    выполняет стандартный python -m unittest discover.
#>
param(
    [string]$ProjectPath = (Get-Location).Path,
    [string[]]$Target = @(),
    [string]$Pattern = "test_*.py",
    [switch]$NoAutoEnsure = $false
)

$ErrorActionPreference = "Continue"
$env:PYTHONIOENCODING = "utf-8"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if ($ProjectPath -and (Test-Path -LiteralPath $ProjectPath)) {
    $ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path
}

Write-Host "`n=== [Project Guardian] Запуск тестов (run-tests.ps1) ===" -ForegroundColor Cyan
Write-Host "Целевой путь: $ProjectPath" -ForegroundColor Gray

# 1. Поиск интерпретатора Python (приоритет .venv)
$pyExe = $null
$p1 = Join-Path $ProjectPath ".venv\Scripts\python.exe"
$p2 = Join-Path $ProjectPath "venv\Scripts\python.exe"
$p3 = Join-Path (Get-Location).Path ".venv\Scripts\python.exe"
$venvPaths = @($p1, $p2, $p3)

foreach ($vp in $venvPaths) {
    if (Test-Path -LiteralPath $vp) {
        $pyExe = $vp
        Write-Host "Используется venv: $vp" -ForegroundColor DarkGray
        break
    }
}
if (-not $pyExe) {
    $cmdPy = Get-Command python -ErrorAction SilentlyContinue
    if ($cmdPy) {
        $pyExe = $cmdPy.Source
    } else {
        Write-Host "[FAIL] Python не найден в системе!" -ForegroundColor Red
        exit 2
    }
}

# 2. Проверка наличия pytest
function Test-HasPytest {
    param([string]$pythonPath)
    $null = & $pythonPath -m pytest --version 2>&1
    return ($LASTEXITCODE -eq 0)
}

$hasPytest = Test-HasPytest -pythonPath $pyExe

# 3. Auto-Ensure: если pytest отсутствует и не отключен флаг -NoAutoEnsure
if (-not $hasPytest -and -not $NoAutoEnsure) {
    Write-Host "[guardian] pytest не обнаружен -> запуск Auto-Ensure..." -ForegroundColor Yellow
    $uvCmd = Get-Command uv -ErrorAction SilentlyContinue
    if ($uvCmd) {
        Write-Host "Установка pytest через uv pip install..." -ForegroundColor Cyan
        & uv pip install --system pytest 2>&1 | Out-Null
    } else {
        Write-Host "Установка pytest через pip install..." -ForegroundColor Cyan
        & $pyExe -m pip install pytest 2>&1 | Out-Null
    }
    $hasPytest = Test-HasPytest -pythonPath $pyExe
    if ($hasPytest) {
        Write-Host "[guardian] pytest успешно установлен и верифицирован!" -ForegroundColor Green
    } else {
        Write-Host "[guardian] Не удалось установить pytest, переключение на стандартный unittest." -ForegroundColor Yellow
    }
}

# 4. Обнаружение тестов Python
$testFiles = @()
$d1 = Join-Path $ProjectPath "tests"
$d2 = Join-Path $ProjectPath "test"
$testDirs = @($d1, $d2)

foreach ($td in $testDirs) {
    if (Test-Path -LiteralPath $td) {
        $found = Get-ChildItem -LiteralPath $td -Filter $Pattern -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch "[\\/](\.git|\.backups|node_modules|\.venv|venv|scratch|graphify-out)[\\/]" }
        if ($found) { $testFiles += $found }
    }
}
if ($testFiles.Count -eq 0) {
    $testFiles = @(Get-ChildItem -LiteralPath $ProjectPath -Filter $Pattern -File -Depth 2 -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch "[\\/](\.git|\.backups|node_modules|\.venv|venv|scratch|graphify-out)[\\/]" })
}

# Если есть package.json и нет тестов Python — пробуем npm test
if ($testFiles.Count -eq 0) {
    $pkgJson = Join-Path $ProjectPath "package.json"
    if (Test-Path -LiteralPath $pkgJson) {
        try {
            $pkg = Get-Content -LiteralPath $pkgJson -Raw | ConvertFrom-Json
            if ($pkg.scripts.test -and $pkg.scripts.test -notmatch "no test specified") {
                Write-Host "Обнаружен npm test. Запуск JS тестов..." -ForegroundColor Cyan
                & npm test --prefix $ProjectPath
                exit $LASTEXITCODE
            }
        } catch {}
    }
    Write-Host "[WARN] Тесты не обнаружены (шаблон $Pattern в $ProjectPath)." -ForegroundColor Yellow
    exit 0
}

Write-Host "Обнаружено тестовых файлов Python: $($testFiles.Count)" -ForegroundColor Gray

# 5. Выбор раннера и запуск
$testExitCode = 0
if ($hasPytest) {
    Write-Host "Запуск через pytest..." -ForegroundColor Green
    if ($Target.Count -gt 0) {
        & $pyExe -m pytest @Target -v
    } else {
        & $pyExe -m pytest $ProjectPath -v
    }
    $testExitCode = $LASTEXITCODE
} else {
    Write-Host "Запуск через стандартный unittest..." -ForegroundColor Cyan
    if ($Target.Count -gt 0) {
        & $pyExe -m unittest @Target -v
    } else {
        # Запуск через unittest discover
        $startDir = if (Test-Path -LiteralPath (Join-Path $ProjectPath "tests")) { Join-Path $ProjectPath "tests" } else { $ProjectPath }
        & $pyExe -m unittest discover -s $startDir -p $Pattern -v
    }
    $testExitCode = $LASTEXITCODE
}

# 6. Анализ результата
if ($testExitCode -eq 0) {
    Write-Host "`n[TDD GREEN] Все тесты успешно пройдены (exit code 0)." -ForegroundColor Green
} else {
    Write-Host "`n[TDD RED / FAIL] Обнаружены падения тестов (exit code $testExitCode)." -ForegroundColor Red
}

exit $testExitCode
