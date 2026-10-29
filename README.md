# Project Guardian — Universal Development Guardian for Antigravity

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Windows PowerShell](https://img.shields.io/badge/Platform-PowerShell-blue.svg)]()
[![Target: Web | Desktop | Firmware](https://img.shields.io/badge/Target-Web%20%7C%20Desktop%20%7C%20Firmware-green.svg)]()

**Project Guardian** — универсальный скилл и набор глобальных правил для Google Antigravity и Gemini CLI.

Адаптирован под любые задачи:
- 🌐 **Веб-сайты и веб-приложения** (Frontend, Backend, Fullstack, REST API)
- 🖥️ **Программы для ПК** (PyQt6/PySide, C# .NET, Electron, сборка `.exe` и инсталляторов)
- 🔥 **Прошивки микроконтроллеров** (ARM Cortex, STM32, Teensy, ESP32, PlatformIO)

---

## Ключевые возможности

1. 🚦 **Security Gate (исполняемый)**: `security-gate.ps1` находит утёкшие секреты, отключённую
   авторизацию, `curl | sh`, `shell=True`, `verify=False` и синтаксические ошибки. Возвращает код 1 —
   коммит не проходит, пока не исправлено. Осознанные исключения — `.security-gate-allow` с причиной.
2. 🔄 **Git Auto-Commit** (пуш только по явному `-Push`): коммит при наличии `remote`.
3. 🧠 **Universal Project Memory (`PROJECT_STATE.md`)**: сохранение контекста проекта — агент сразу понимает стек, команды запуска и статус при открытии нового диалога.
4. 🛡️ **Safety Checkpoints & Easy Rollback**: бэкапы перед опасными правками и мгновенный откат (`rollback.ps1 -List`).
5. 📦 **Несгораемые архивы релизов без перезаписи**:
   - Для **прошивок**: сохранение бинарников (`.bin`, `.hex`, `.elf`, `.uf2`) в `.backups/firmware_success_YYYY-MM-dd_HH-mm-ss/`.
   - Для **ПК-программ**: сохранение исполняемых файлов (`.exe`, `.msi`, `.dll`) в `.backups/desktop_release_YYYY-MM-dd_HH-mm-ss/` с паспортом SHA256.
   - Для **веб-сайтов**: сохранение продакшн сборки (`dist/`, `build/`, `out/`) в `.backups/web_release_YYYY-MM-dd_HH-mm-ss/`.
6. 🔍 **Автономный подбор скиллов**: подтягивание нужных скиллов из каталога [sickn33/agentic-awesome-skills](https://github.com/sickn33/agentic-awesome-skills) под нужный стек без напоминаний.
7. 📊 **Mandatory Graphify**: построение графа зависимостей кодовой базы для любого проекта.
8. ⚡ **Ponytail Pragmatic Mode**: жесткий режим борьбы с оверинжинирингом — чистый минимальный код, экономия более 50% токенов, отсечение ненужных библиотек. Не применяется к аутентификации и обработке секретов.
9. 🩺 **Productivity Suite**: экспресс-диагностика окружения (`doctor.ps1`), бесшовный перенос контекста в новый диалог (`prepare-handoff.ps1`), безопасная очистка бэкапов (`clean-backups.ps1`), сканер секретов и генератор `.env.example` (`gen-env.ps1`), авто-тестирование перед коммитом (`checkpoint.ps1 -Verify`).

---

## Структура

```text
/
├── SKILL.md                          # Манифест скилла с триггерами и регламентом
├── scripts/
│   ├── checkpoint.ps1                # Универсальный скрипт бэкапа (код / web / desktop / firmware / -Verify)
│   ├── doctor.ps1                    # Экспресс-диагностика окружения, Git и компонентов
│   ├── prepare-handoff.ps1           # Генерация ультракомпактного контекста для нового диалога (.agents/HANDOFF.md)
│   ├── clean-backups.ps1             # Безопасная ротация промежуточных бэкапов (-DryRun)
│   ├── gen-env.ps1                   # Сканер кодовой базы и генератор шаблона .env.example
│   ├── security-gate.ps1             # Исполняемый гейт: секреты, антипаттерны, синтаксис (exit 1)
│   ├── record-failure.ps1            # Фиксация инцидентов в docs/ERRORS_AND_FAILURES.md
│   ├── rollback.ps1                  # Менеджер отката с просмотром точек (-List)
│   └── install-skill.ps1             # Автономный загрузчик скиллов из GitHub
├── references/
│   └── PROJECT_STATE_TEMPLATE.md     # Универсальный шаблон памяти проекта
├── .gitignore
├── PROJECT_STATE.md                  # Память данного репозитория
└── README.md
```

---

## Использование

### 1. Чекпоинт кода (перед правками)
```powershell
& ".\scripts\checkpoint.ps1" -Message "Рефакторинг роутов"
```

### 2. Релиз веб-сайта
```powershell
& ".\scripts\checkpoint.ps1" -Message "Релиз v1.0.0" -Category "Web" -Release
```

### 3. Релиз программы для ПК
```powershell
& ".\scripts\checkpoint.ps1" -Message "Сборка ПК-версии v1.2" -Category "Desktop" -Release
```

### 4. Удачная прошивка микроконтроллера
```powershell
& ".\scripts\checkpoint.ps1" -Message "Успешный flash v2.1" -Firmware
```

### 5. Просмотр и откат
```powershell
# Список сохраненных точек:
& ".\scripts\rollback.ps1" -List

# Откат к последней точке:
& ".\scripts\rollback.ps1"

# Откат к конкретной точке:
& ".\scripts\rollback.ps1" -TargetCheckpoint "desktop_release_2026-09-28_15-00-00"
```

### 6. Обязательный security-gate перед коммитом

```powershell
& ".\scripts\security-gate.ps1" -ProjectPath "E:\Projects\MyProject"
# exit 0 — можно коммитить; exit 1 — есть находки, чинить
```

Что проверяется: секреты и приватные ключи в трекаемых файлах, дефолтные пароли,
`auth.enabled = false`, `verify=False`, `shell=True`, `curl | sh`, `python3 -c`,
`chmod 777`, wildcard CORS, синтаксис Python/JS/sh, а с `-CheckLinks` — доступность URL.

Осознанные исключения (например, стандартный пароль панели по требованию владельца)
живут в `<проект>/.security-gate-allow`, по строке с причиной после `#`. Исключения печатаются
в отчёте — они не «зеленеют» молча, но и не блокируют сборку.
