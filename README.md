# Project Guardian — Skill & Autonomous Rules for Antigravity

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Windows PowerShell](https://img.shields.io/badge/Platform-PowerShell-blue.svg)]()
[![Antigravity / Gemini CLI](https://img.shields.io/badge/Target-Antigravity%20%7C%20Gemini%20CLI-orange.svg)]()

**Project Guardian** — скилл и комплекс правил автономной работы для Google Antigravity и Gemini CLI.

Он решает 6 ключевых задач при работе с AI-агентом:
1. 🔄 **Git Auto-Push**: автоматический коммит и `git push` при наличии настроенного `remote`.
2. 🧠 **Project Memory (`PROJECT_STATE.md`)**: единый файл контекста проекта — агент сразу понимает суть и статус задачи при открытии нового диалога без повторных объяснений.
3. 🛡️ **Safety Checkpoints & Easy Rollback**: резервное копирование рабочего кода перед рискованными правками с возможностью мгновенного отката (`rollback.ps1`).
4. 🔥 **Firmware Flash Dedicated Backups**: при каждой успешной прошивке микроконтроллера/устройства создается отдельный изолированный бэкап исходников и бинарных артефактов (`.bin`, `.hex`, `.elf`, `.uf2`, `.dfu`) с аннотированным тегом в Git.
5. 🔍 **Autonomous Skill Discovery**: самостоятельный поиск и установка недостающих скиллов из каталога [sickn33/agentic-awesome-skills](https://github.com/sickn33/agentic-awesome-skills) без напоминаний.
6. 📊 **Mandatory Graphify**: обязательное построение графа знаний и связей архитектуры проекта с помощью `graphify`.

---

## Структура

```text
/
├── SKILL.md                          # Манифест скилла с триггерами и регламентом
├── scripts/
│   ├── checkpoint.ps1                # Создание бэкапа (код / прошивка), коммит и git push
│   ├── rollback.ps1                  # Мгновенный откат файлов из точки восстановления
│   └── install-skill.ps1             # Автономная загрузка скиллов из GitHub
├── references/
│   └── PROJECT_STATE_TEMPLATE.md     # Эталонный шаблон памяти проекта (PROJECT_STATE.md)
├── .gitignore
├── PROJECT_STATE.md                  # Память данного репозитория
└── README.md
```

---

## Установка

### Глобальная установка (для всех проектов на компьютере)
Скопируйте файлы скилла в глобальную директорию Antigravity:
```powershell
$dest = "$env:USERPROFILE\.gemini\config\skills\project-guardian"
Copy-Item -Path ".\*" -Destination $dest -Recurse -Force
```

### Настройка глобальных правил в `AGENTS.md`
Добавьте в `~/.gemini/config/AGENTS.md`:
```markdown
# Autonomous Workflow & Safety Rules

1. Autonomous Skill Discovery: Если для новой задачи нет локального скилла, агент автономно устанавливает его из sickn33/agentic-awesome-skills через install-skill.ps1.
2. Mandatory Graphify: Для анализа архитектуры и кодовой базы всегда использовать graphify.
3. Persistent Project Memory: Поддерживать PROJECT_STATE.md в корне каждого проекта.
4. Safety Checkpoints: Перед изменением кода создавать чекпоинт через checkpoint.ps1.
5. Firmware Flash Dedicated Backup: При каждой удачной прошивке создавать отдельный бэкап через checkpoint.ps1 -Firmware.
6. Git Auto-Push: При наличии remote отправлять изменения и теги в удаленный репозиторий.
```

---

## Использование

### 1. Создание обычной контрольной точки (Checkpoint)
```powershell
& ".\scripts\checkpoint.ps1" -Message "Реализована авторизация" -Push
```
- Делает снимок в `.backups/checkpoint_<timestamp>/`.
- Индексирует и коммитит изменения в Git.
- Если есть `remote` — пушит в текущую ветку.
- Записывает событие в `PROJECT_STATE.md`.

### 2. Бэкап при удачной прошивке (Firmware Flash)
```powershell
& ".\scripts\checkpoint.ps1" -Message "Успешная прошивка v1.2: стабильный BLE стек" -Firmware
```
- Создает отдельную директорию `.backups/firmware_success_<timestamp>/`.
- Сохраняет полный снимок проекта и находит скомпилированные бинарники (`.bin`, `.hex`, `.elf`, `.uf2`) в подпапку `firmware_binaries/`.
- Создает Git-тег `firmware-flash-<timestamp>` и пушит в remote (`--tags`).
- Добавляет отметку `🔥 УДАЧНАЯ ПРОШИВКА` в `PROJECT_STATE.md`.

### 3. Откат (Rollback)
```powershell
& ".\scripts\rollback.ps1"
```
- Мгновенно восстанавливает файлы проекта из последней рабочей точки.
- Можно передать точное имя точки: `-TargetCheckpoint "firmware_success_20260923_104500"`.

### 4. Установка нового скилла из каталога
```powershell
& ".\scripts\install-skill.ps1" -SkillName "fastapi-expert"
```
- Скачивает скилл и все его файлы напрямую из `sickn33/agentic-awesome-skills` в локальную конфигурацию.
