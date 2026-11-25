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
   авторизацию, `curl | sh`, `shell=True`, `verify=False` и синтаксические ошибки (Python, Node.js, Bash, PowerShell). Возвращает код 1 —
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
9. 🩺 **Productivity Suite**: единый CLI-фасад (`guardian.ps1`), диагностика окружения (`doc`), честный аудит обвязки Harness² (`harness`), зондирование скиллов (`probe`), Zero-Copy авто-создание нового диалога (`handoff` / `new-chat`), авто-раннер тестов (`test`), безопасная очистка бэкапов (`clean`), генератор `.env.example` (`env`), счетчик шагов сессии (`steps`).
10. 🗂️ **Multi-Project Workspace Protection**: изолированные чекпоинты и проверки подпроектов в составных воркспейсах/монорепозиториях без раздувания архивов родительской папки.

---

## Структура

```text
/
├── guardian.ps1                      # Единый CLI-фасад (тонкий шим к scripts/guardian.ps1)
├── SKILL.md                          # Компактный манифест скилла v2.4
├── scripts/
│   ├── guardian.ps1                  # Консолидированный фасад CLI (алиасы cp, doc, gate, test, harness, probe, handoff...)
│   ├── checkpoint.ps1                # Бэкапы (код / web / desktop / firmware / -Verify / -SubProject / -Push)
│   ├── doctor.ps1                    # Экспресс-диагностика окружения, Git и компонентов (-Harness)
│   ├── audit-harness.ps1             # Честный аудит 8 измерений обвязки (Harness² Audit)
│   ├── probe-skill.ps1               # Зондирование скиллов перед установкой (Harness² Probe)
│   ├── run-tests.ps1                 # Авто-раннер тестов с Auto-Ensure (pytest / unittest / npm)
│   ├── prepare-handoff.ps1           # Zero-Copy авто-создание нового диалога в Antigravity (.agents/HANDOFF.md)
│   ├── session-steps.ps1             # Счетчик шагов активной сессии и контроль перегрузки контекста
│   ├── clean-backups.ps1             # Безопасная ротация промежуточных бэкапов (-Keep, -DryRun)
│   ├── gen-env.ps1                   # Сканер кодовой базы и генератор шаблона .env.example
│   ├── security-gate.ps1             # Исполняемый гейт: секреты, антипаттерны, AST, BOM, PS-001, REC-001 (exit 1)
│   ├── record-failure.ps1            # Фиксация инцидентов в docs/ERRORS_AND_FAILURES.md
│   ├── rollback.ps1                  # Менеджер отката с просмотром точек (-List)
│   ├── new-scratch.ps1               # Безопасный генератор scratch-скриптов (UTF-8, авто-подтягивание кредов)
│   ├── install-skill.ps1             # Автономный загрузчик скиллов из GitHub с Probe Gate
│   ├── check-new-skills.ps1          # Мониторинг новых скиллов в апстриме
│   ├── add-recommendation.ps1        # Формирование рекомендаций для внешнего проекта или скилла
│   └── send-email.ps1                # Универсальный почтовый шлюз (SSL/TLS, вложения)
├── references/                       # Модульные справочники (Selective TDD, Harness², Multi-Project, Email, Шаблон памяти)
├── tests/
│   └── test_guardian.py              # Поведенческие автотесты (pytest)
├── .gitignore
├── PROJECT_STATE.md                  # Оперативная память репозитория
├── CHANGELOG.md
└── README.md
```

---

## Использование (единый фасад `guardian.ps1`)

### 1. Базовые команды
```powershell
.\guardian.ps1 doc                                    # Диагностика окружения и проекта
.\guardian.ps1 gate                                   # Обязательный Security Gate (exit 0 / 1)
.\guardian.ps1 test                                   # Запуск автотестов
.\guardian.ps1 harness                                # Аудит 8 измерений обвязки (Harness²)
.\guardian.ps1 cp -Message "Рефакторинг роутов"       # Локальный чекпоинт кода (без push)
.\guardian.ps1 handoff -NextGoal "Следующий этап"     # Zero-Copy переход в новый диалог
```

### 2. Релизные несгораемые архивы
```powershell
.\guardian.ps1 cp -Message "Релиз v1.0.0" -Category "Web" -Release
.\guardian.ps1 cp -Message "Сборка ПК-версии v1.2" -Category "Desktop" -Release
.\guardian.ps1 cp -Message "Успешный flash v2.1" -Firmware
```

### 3. Просмотр и откат
```powershell
.\guardian.ps1 rb -List
.\guardian.ps1 rb
.\guardian.ps1 rb -TargetCheckpoint "desktop_release_2026-09-28_15-00-00"
```

### 4. Security Gate и allowlist

Что проверяется: секреты и приватные ключи в трекаемых файлах, дефолтные пароли,
`auth.enabled = false`, `verify=False`, `shell=True`, `curl | sh`, `python3 -c`,
`chmod 777`, wildcard CORS, `Test-Path` без `-LiteralPath` (`PS-001`), UTF-8 BOM в `.sh`/`.kl` (`SYNTAX-BOM`),
синтаксис Python/JS/sh/ps1 и архивация закрытых рекомендаций (`REC-001`).

Осознанные исключения живут в `<проект>/.security-gate-allow` в строгом формате `<RULE-ID> <путь[:строка]> # причина`. Исключения печатаются в отчёте — они не «зеленеют» молча, но и не блокируют сборку.

### 5. Изоляция в составных воркспейсах (монорепозиториях)

Если в одной общей папке находятся несколько отдельных проектов (например, `Router_Workspace/Router_api`, `Router_Workspace/Opds`):
```powershell
.\guardian.ps1 cp -ProjectPath "E:\Projects\Router_Workspace\Opds" -Message "Обновление OPDS"
# или коротко:
.\guardian.ps1 cp -SubProject "Opds" -Message "Обновление OPDS"
```
Скрипт автоматически определяет активный подпроект по Git-изменениям и сохраняет снимки строго в `Opds/.backups/`, а при создании бэкапа родительской папки исключает вложенные проекты, защищая диск от гигабайтных дубликатов.
