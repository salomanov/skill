param(
    [string]$ProjectPath = (Get-Location).Path,
    [string]$OutputFile = ".env.example"
)

$ErrorActionPreference = "Stop"

Write-Host "`n=== [Project Guardian] Генератор безопасного шаблона .env.example ===" -ForegroundColor Cyan
Write-Host "Проект: $ProjectPath"

$targetPath = Join-Path $ProjectPath $OutputFile

# Список системных переменных, которые игнорируем
$systemVars = @("PATH", "HOME", "USER", "USERNAME", "TEMP", "TMP", "OS", "SHELL", "PWD", "TERM", "LANG", "NODE_ENV", "PSMODULEPATH")

$excludeDirs = @(".git", ".backups", "node_modules", ".venv", "venv", "__pycache__", "dist", "build", ".next", ".turbo")
$includeExts = @("*.py", "*.js", "*.ts", "*.jsx", "*.tsx", "*.php", "*.cs", "*.sh", "*.env", "*.env.sample")

Write-Host "Сканирование кодовой базы на вызовы переменных окружения..." -ForegroundColor Gray
$files = Get-ChildItem -Path $ProjectPath -Recurse -File -Include $includeExts -ErrorAction SilentlyContinue | Where-Object {
    $full = $_.FullName
    $skip = $false
    foreach ($ex in $excludeDirs) {
        if ($full -like "*\$ex\*") { $skip = $true; break }
    }
    -not $skip
}

$detectedVars = [System.Collections.Generic.HashSet[string]]::new()

$patterns = @(
    'os\.(?:environ\.get|getenv)\s*\(\s*["'']([A-Za-z0-9_]+)["'']',
    'os\.environ\s*\[\s*["'']([A-Za-z0-9_]+)["'']\s*\]',
    'process\.env\.([A-Za-z0-9_]+)',
    'process\.env\s*\[\s*["'']([A-Za-z0-9_]+)["'']\s*\]',
    'import\.meta\.env\.([A-Za-z0-9_]+)',
    'getenv\s*\(\s*["'']([A-Za-z0-9_]+)["'']\s*\)',
    '\$_ENV\s*\[\s*["'']([A-Za-z0-9_]+)["'']\s*\]',
    'Environment\.GetEnvironmentVariable\s*\(\s*["'']([A-Za-z0-9_]+)["'']'
)

foreach ($f in $files) {
    try {
        $content = Get-Content $f.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        if (-not $content) { continue }

        foreach ($p in $patterns) {
            $matches = [regex]::Matches($content, $p)
            foreach ($m in $matches) {
                if ($m.Groups.Count -gt 1) {
                    $varName = $m.Groups[1].Value.Trim()
                    if ($varName.Length -gt 1 -and $systemVars -notcontains $varName.ToUpper()) {
                        [void]$detectedVars.Add($varName)
                    }
                }
            }
        }
    } catch {}
}

Write-Host "Обнаружено уникальных переменных: $($detectedVars.Count)" -ForegroundColor Cyan

if ($detectedVars.Count -eq 0) {
    Write-Host "В коде не найдено явных обращений к переменным окружения." -ForegroundColor Yellow
    return
}

# Формирование контента .env.example
$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("# Auto-generated template by Project Guardian (gen-env.ps1)")
[void]$sb.AppendLine("# Скопируйте этот файл в .env и укажите реальные значения локально.")
[void]$sb.AppendLine("# ВНИМАНИЕ: файл .env с реальными секретами НИКОГДА не коммитится в Git!")
[void]$sb.AppendLine("# Сформировано: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))`n")

$sorted = $detectedVars | Sort-Object
foreach ($v in $sorted) {
    [void]$sb.AppendLine("$v=")
    Write-Host "  + $v=" -ForegroundColor Gray
}

[System.IO.File]::WriteAllText($targetPath, $sb.ToString(), [System.Text.Encoding]::UTF8)
Write-Host "`n[OK] Шаблон успешно сохранен в: $targetPath" -ForegroundColor Green
