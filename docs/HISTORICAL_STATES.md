# Архив Истории Изменений: Project Guardian (v1.1.0 — v1.8.1)

> Данный документ содержит архивные чекпоинты и подробное описание релизов линейки v1.x проекта Project Guardian.
> Актуальное состояние и текущие версии v2.x отслеживаются в [PROJECT_STATE.md](../PROJECT_STATE.md).

---

## 1. Чекпоинты и Релизы линейки v1.x

- 🛡️ **Чекпоинт** [2026-11-21 20:24:21] (метка: 2026-11-21_20-24-21): v1.8.1 Auto-Ensure Test Runner and router-ops domain extraction

- 🛡️ **Чекпоинт** [2026-11-21 19:03:49] (метка: 2026-11-21_19-03-49): Pre-v1.8.1 Auto-Ensure Test Runner and run-tests script

- 🛡️ **Чекпоинт** [2026-11-20 17:40:46] (метка: 2026-11-20_17-40-46): v1.8.0 Auto-Graphify, Dialog Title Preservation, Failure & Recommendation Gates

- 🛡️ **Чекпоинт** [2026-11-18 21:25:28] (метка: 2026-11-18_21-25-28): Pre-v1.8.0 Audit, Dialog Title Preservation, Auto-Graphify & Failure/Recommendation Gates

- 🛡️ **Чекпоинт** [2026-11-18 10:59:55] (метка: 2026-11-18_10-59-55): v1.7.11 Universal Email Dispatcher

- 🛡️ **Чекпоинт** [2026-11-15 23:34:57] (метка: 2026-11-15_23-34-57): v1.7.10 Targeted Session Step Counter & False Alert Prevention

- 🛡️ **Чекпоинт** [2026-11-15 22:52:44] (метка: 2026-11-15_22-52-44): v1.7.9 Mechanical Step Counter & Context Hygiene Guard

- 🛡️ **Чекпоинт** [2026-11-15 22:48:29] (метка: 2026-11-15_22-48-29): Pre-v1.7.9 Mechanical Step Counter

- 🛡️ **Чекпоинт** [2026-11-15 20:48:11] (метка: 2026-11-15_20-48-11): v1.7.8 Android Mobile & Path Invariants Suite

- 🛡️ **Чекпоинт** [2026-11-15 20:46:54] (метка: 2026-11-15_20-46-54): failure: Краш Paho MQTT из-за потери META-INF/services и крах apktool на кириллических путях

- 🛡️ **Чекпоинт** [2026-11-15 20:45:53] (метка: 2026-11-15_20-45-53): Pre-v1.7.8 PATH-001 and Mobile Suite

- 🛡️ **Чекпоинт** [2026-11-15 16:37:09] (метка: 2026-11-15_16-37-09): v1.7.7 Selective TDD by Default & Verification Gate

- 🛡️ **Чекпоинт** [2026-11-15 16:35:48] (метка: 2026-11-15_16-35-48): Pre-v1.7.7 Selective TDD by Default

- 🛡️ **Чекпоинт** [2026-11-14 11:55:10] (метка: 2026-11-14_11-55-10): docs: classify upstream vs custom skills and update ponytail + rea (v1.7.6)

### [2026-11-14 11:55]
- **Что сделано**: Уточнена классификация скиллов и обновлены upstream-скиллы Ponytail и REA (v1.7.6):
  1. Разделены контуры скиллов:
     - **Кастомные авторские скиллы пользователя** (не перезаписываются): `project-guardian`, `router-ops`, `scan-to-epub-pro`.
     - **Внешние upstream-скиллы**: `ponytail`, `ponytail-review`, `ponytail-audit` (из репозитория `DietrichGebert/ponytail`), `rea` (из `morluto/rea`), а также каталог `sickn33/agentic-awesome-skills`.
  2. Обновлены до актуальных upstream-релизов:
     - `ponytail` (SKILL.md обновлен из `DietrichGebert/ponytail`)
     - `ponytail-review` (обновлен из `DietrichGebert/ponytail`)
     - `ponytail-audit` (обновлен из `DietrichGebert/ponytail`)
     - `rea` (синхронизирован с установленным CLI `rea v6.8.0`)
- **Чекпоинт**: Релиз v1.7.6 (Upstream Taxonomy & Ponytail/REA Refresh).

- 🛡️ **Чекпоинт** [2026-11-14 11:48:23] (метка: 2026-11-14_11-48-23): perf: optimize timeout and update core skills batch (v1.7.5)

- 🛡️ **Чекпоинт** [2026-11-14 10:50:23] (метка: 2026-11-14_10-50-23): feat: add check-new-skills tool and update core packages to latest (v1.7.4)

### [2026-11-14 10:50]
- **Что сделано**: Реализован механизм обнаружения новых скиллов и обновлены ключевые рабочие пакеты (Skill Catalog Discovery & Packages Suite v1.7.4):
  1. Обновлены ключевые библиотеки окружения через `uv pip install --system -U`:
     - `graphifyy`: 0.9.104 -> 0.9.108 (построение графов знаний)
     - `playwright`: 1.64.1 -> 1.65.2 (веб-скриншоты и E2E)
     - `tinytuya`: 1.20.0 -> 1.21.1 (работа с устройствами Tuya на роутере/термостате)
     - `pyinstaller-hooks-contrib`: 2026.9 -> 2026.10 (сборка десктопных .exe)
  2. Разработан скрипт `scripts/check-new-skills.ps1` для автоматического мониторинга свежих поступлений скиллов в апстрим `sickn33/agentic-awesome-skills` (парсинг релизов, извлечение добавленных скиллов, сверка с установленными в `~/.gemini/config/skills` и фильтрация по ключевым словам).
  3. В Раздел 6 `SKILL.md` добавлено руководство по использованию `check-new-skills.ps1`.
- **Чекпоинт**: Релиз v1.7.4 (Skill Catalog Discovery Suite).

- 🛡️ **Чекпоинт** [2026-11-14 10:44:40] (метка: 2026-11-14_10-44-40): feat: implement skill & tool freshness check and update policy (v1.7.3)

### [2026-11-14 10:45]
- **Что сделано**: Внедрен регламент проактивной проверки свежести скиллов и рабочих пакетов (Skill & Tool Freshness Policy v1.7.3):
  1. В `scripts/install-skill.ps1` добавлены режимы `-CheckOnly` (проверка обновлений в upstream без перезаписи) и `-Update` (принудительное обновление до актуального релиза GitHub).
  2. В Разделе 6 `SKILL.md` закреплено железное правило: при начале работы с профильным скиллом или ключевым рабочим инструментом (`graphifyy`, `tinytuya`, `playwright`, `platformio`) агент проверяет актуальность версий и проактивно предлагает обновиться пользователю перед выполнением задачи.
- **Чекпоинт**: Релиз v1.7.3 (Proactive Freshness & Update Suite).

- 🛡️ **Чекпоинт** [2026-11-12 16:51:32] (метка: 2026-11-12_16-51-32): feat: implement recommendations lifecycle, status tracking and applied archiving (v1.7.2)

### [2026-11-12 16:55]
- **Что сделано**: Внедрен Регламент жизненного цикла `AGENT_RECOMMENDATIONS.md` (Архивация и гигиена контекста v1.7.2) по итогам аудита диалога `6dff03e2-0913-483a-a1af-a5c0daa95304`:
  1. В Раздел 13 `SKILL.md` закреплены обязательные требования к жизненному циклу рекомендаций:
     - Обязательная маркировка статуса задач: `[ ] ТРЕБУЕТ ВНЕДРЕНИЯ` / `[x] ВЫПОЛНЕНО (ГГГГ-ММ-ДД)`.
     - Обязательный перенос закрытых рекомендаций в архив `docs/APPLIED_RECOMMENDATIONS.md` для сохранения компактности активного файла.
     - Полная очистка или архивация `AGENT_RECOMMENDATIONS.md` при закрытии всех входящих задач.
  2. Создан файл архива `docs/APPLIED_RECOMMENDATIONS.md`.
  3. В корень проекта добавлен актуальный `AGENT_RECOMMENDATIONS.md` с синхронизацией открытых задач по C++ сырым строкам (`R"raw(...)raw"`) и JSON-подстрокам.
- **Чекпоинт**: Релиз v1.7.2 (Recommendations Lifecycle & Context Hygiene Suite). (Журнал сессий)

- 🛡️ **Чекпоинт** [2026-11-07 14:02:03] (метка: 2026-11-07_14-02-03): feat: v1.7.1 WildcardPatternException LiteralPath fix and Windows CRLF hardening

### [2026-11-07 14:00]
- **Что сделано**: Анализ и внедрение новой порции рекомендаций из `AGENT_RECOMMENDATIONS.md` (сессия диагностики `Router_Workspace`):
  1. **Фикс `WildcardPatternException`**: В `security-gate.ps1` вызовы проверки файлов переведены с `-Path` на `-LiteralPath` (строки 178, 223, 266), предотвращая аварийные сбои PowerShell при наличии квадратных скобок в путях к файлам.
  2. **Dropbear SSH & SFTP Reminder**: В генератор `new-scratch.ps1` добавлена подсказка о невозможности использования `open_sftp()` на роутерах с Dropbear и пример надежной передачи файлов через `exec_command("cat > path")`.
  3. **Windows CRLF vs LF для `edit_file`**: В `SKILL.md` (раздел 10.9) и `AGENTS.md` добавлено железное правило действий при ошибке `target content not found`.
  4. Проверена безопасность через `security-gate.ps1` и очищен файл `AGENT_RECOMMENDATIONS.md`.
- **Чекпоинт**: Релиз v1.7.1 (WildcardPatternException Fix & Windows CRLF Hardening).

- 🛡️ **Чекпоинт** [2026-11-07 13:46:22] (метка: 2026-11-07_13-46-22): feat: v1.7.0 Executable Barriers Suite with new-scratch generator and No-Polling Delegator rule

### [2026-11-07 13:45]
- **Что сделано**: Анализ сбоя диалога `6dff03e2` и внедрение комплекса Executable Barriers (v1.7.0):
  1. **Скрипт `scripts/new-scratch.ps1`**: Разработан безопасный генератор scratch-скриптов для Python и PowerShell. Автоматически гарантирует `sys.stdout.reconfigure(encoding='utf-8')` и UTF-8 BOM, а при флаге `-WithSSH` парсит проект на наличие боевых параметров (`host`, `port`, `user`, `password` из `deploy.py` / `.env`), исключая ошибки `SSHException` и крах `CP1251`.
  2. **Запрет поллинга Delegator**: В глобальные правила `~/.gemini/config/AGENTS.md` и `SKILL.md` (раздел 10.8) внедрено жесткое правило: при уходе Delegator в фон агент отправляет пользователю 1 сообщение и немедленно останавливает ход, дожидаясь `Reactive Wakeup`. Любые циклы с `manage_task status` и `sleep.py` категорически запрещены.
  3. **Контекстная гигиена**: В Rule 0 зафиксирован норматив передачи сессии при приближении к 150–200 шагам через `prepare-handoff.ps1`.
- **Чекпоинт**: Релиз v1.7.0 (Executable Barriers & Stability Suite).

- 🛡️ **Чекпоинт** [2026-11-06 03:28:14] (метка: 2026-11-06_03-28-14): feat: resolve second batch of AGENT_RECOMMENDATIONS for credentials and test discovery

### [2026-11-06 03:25]
- **Что сделано**: Внедрены рекомендации из `AGENT_RECOMMENDATIONS.md` (входящие из проекта NanoOPDS / Router_Workspace):
  1. **Правило контекстных параметров (Read Credentials & Config First)**: В `SKILL.md` (раздел 10.6) и в глобальные правила `~/.gemini/config/AGENTS.md` (Правило 10) внедрен строгий запрет на хардкод и угадывание учетных данных при создании scratch-скриптов. Агент обязан считывать реальные параметры из конфигураций (`deploy.py`, `.env`, `PROJECT_STATE.md`).
  2. **Таргетированное тестирование (Targeted Test Discovery)**: В `SKILL.md` (раздел 10.7) и `AGENTS.md` зафиксирован запрет неявного вызова `discover()` в корне составных воркспейсов во избежание запуска тестов библиотек из `site-packages`.
  3. **Устойчивый парсинг аргументов PowerShell**: В `checkpoint.ps1`, `record-failure.ps1` и `prepare-handoff.ps1` параметры текстовых сообщений (`-Message`, `-Title`, `-NextGoal`) переведены на поддержку массивов и `ValueFromRemainingArguments`, устраняя ошибки парсера аргументов при вызовах без кавычек.
  4. Обновлены и сохранены с UTF-8 BOM все затронутые скрипты, проверен гейт `security-gate.ps1`.
- **Чекпоинт**: Релиз v1.6.3 (Zero Exit Code 1 Hardening & Argument Robustness).

- 🛡️ **Чекпоинт** [2026-11-06 02:01:05] (метка: 2026-11-06_02-01-05): feat: resolve AGENT_RECOMMENDATIONS for Windows CLI encoding and firmware checkpoints

### [2026-11-06 02:00]
- **Что сделано**: Внедрены исправления по рекомендациям из `AGENT_RECOMMENDATIONS.md` (входящие от проекта «Ночник»):
  1. **Защита от сбоя CP1251 UnicodeEncodeError**: Во всех скриптах PowerShell (`checkpoint.ps1`, `doctor.ps1`, `security-gate.ps1`, `rollback.ps1`, `clean-backups.ps1`, `record-failure.ps1`, `prepare-handoff.ps1`, `gen-env.ps1`, `install-skill.ps1`) внедрена принудительная инициализация кодировки UTF-8 (`$env:PYTHONIOENCODING = "utf-8"`, `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8`, `$OutputEncoding = [System.Text.Encoding]::UTF8`). В манифест `SKILL.md` (раздел 10.2) и шаблон `PROJECT_STATE_TEMPLATE.md` добавлены железные правила запуска PlatformIO CLI (`$env:PYTHONIOENCODING='utf-8'; pio run`).
  2. **Разделение чекпоинтов прошивки**: В `checkpoint.ps1` устранено безусловное присвоение `$Release = $true` для проектов категории `Firmware`. Обычные чекпоинты исходного кода и инциденты `record-failure.ps1` сохраняются как `checkpoint_firmware_*` без создания фиктивных тегов `[SUCCESS FLASH]` и паспортов `RELEASE_INFO.md`. Релизный бэкап `firmware_success_*` с сохранением бинарников, паспортом и уникальным тегом формируется строго по флагу `-Firmware` или `-Release`.
  3. **Обновление rollback.ps1 и doctor.ps1**: В `rollback.ps1` добавлена дифференциация иконок для `checkpoint_firmware_*` (чекпоинт кода) и `firmware_success_*` (удачная прошивка). В `doctor.ps1` скорректирован подсчет несгораемых релизов прошивок.
  4. Все скрипты `.ps1` сохранены с обязательным UTF-8 BOM для надежного парсинга в PowerShell 5.1.
- **Чекпоинт**: Релиз v1.6.2 (Windows CLI UTF-8 Encoding & Firmware Checkpoint Separation).

- 🛡️ **Чекпоинт** [2026-11-04 18:00:39] (метка: 2026-11-04_18-00-39): feat: record-failure subproject auto-detection and isolation
### [2026-11-20 17:40]
- **Что сделано**: Проведён полный аудит всех 35 проектов в `E:\Projects` и внедрён релиз **v1.8.0** (Auto-Graphify, Dialog Title Preservation, Failure & Recommendation Gates):
  1. **Auto-Graphify в `checkpoint.ps1`**: устранены 3 бага, из-за которых `graphify-out/` отсутствовал в 31 из 35 проектов (убрано блокирующее условие `if (Test-Path $graphifyDir)`, добавлено `$ErrorActionPreference = "Continue"` вокруг вызова `python -m graphify`, генерация `.graphifyignore` и `.gitignore` перенесена ДО запуска Graphify).
  2. **Сохранение названия диалога (`scripts/get_dialog_title.py`, `prepare-handoff.ps1`, `checkpoint.ps1`)**: автоматическое чтение `title` из `conversation_summaries.db`, вставка `Тема диалога: <Title>` первой строкой промпта, авто-синхронизация названия в БД при чекпоинте, исправление бага табуляции `` `	ext `` и парсинга `$recentChanges`.
  3. **Исполняемые гейты ошибок и рекомендаций**: создан `scripts/add-recommendation.ps1`, в `record-failure.ps1` добавлен `-RecommendToSkill`, в `checkpoint.ps1` внедрены `FAIL-GUARD`, `REC-GUARD` и `Auto-Git-Init`, в `security-gate.ps1` добавлены правила `REC-001` и `SYNTAX-BOM`, в `doctor.ps1` добавлена диагностика `ERRORS_AND_FAILURES.md` и `AGENT_RECOMMENDATIONS.md`.
  4. **Закрытие рекомендаций и обновление `SKILL.md`**: перенесены в `docs/APPLIED_RECOMMENDATIONS.md` все открытые рекомендации, в `SKILL.md` добавлены разделы 10.11–10.14 (быстрый поиск без `.backups`, коллизия `PROCS=python3` в Entware, `R"rawhtml(...)rawhtml"` в C++, правило BOM и Single Source of Truth для APK/бандлов).
- **Чекпоинт**: Релиз v1.8.0.

### [2026-11-18 10:55]
- **Что сделано**: Внедрен универсальный почтовый шлюз (Релиз v1.7.11):
  1. `scripts/send-email.py` и `scripts/send-email.ps1`: универсальный скрипт отправки писем с поддержкой вложений любого формата, HTML/текста и SSL/TLS (Mail.ru SMTP).
  2. Глобальная конфигурация `~/.gemini/config/email_settings.json` (адрес получателя по умолчанию: `recipient@example.com`, отправитель: `sender@example.com`).
  3. `SKILL.md`: добавлен Раздел 19 «Универсальная отправка на почту» с триггерами *«напиши мне на почту»*, *«скинь мне на почту»*, *«отправь на email»*.
  4. `CHANGELOG.md`: зафиксирован релиз v1.7.11.
- **Чекпоинт**: Релиз v1.7.11 (Universal Email Dispatcher).

### [2026-11-15 23:30]
- **Что сделано**: Устранено ложное срабатывание счетчика шагов на соседних сессиях (Релиз v1.7.10):
  1. `checkpoint.ps1` и `security-gate.ps1`: внедрен приоритетный резолв активной сессии через `$env:ANTIGRAVITY_CONVERSATION_ID` и параметр `-ConversationId`.
  2. Устранена слепая выборка по `LastWriteTime` директории в `Get-ActiveSessionStepCount`, исключен перехват счетчика старых перегруженных сессий (как `236ded68`) при работе в новом диалоге (`0d7841b1`).
  3. `CHANGELOG.md`: зафиксирован релиз v1.7.10.
- **Чекпоинт**: Релиз v1.7.10 (Targeted Session Step Counter & False Alert Prevention).

### [2026-11-15 22:50]
- **Что сделано**: Внедрен модуль аппаратного контроля длины сессии и контекстной гигиены (Релиз v1.7.9):
  1. `scripts/checkpoint.ps1` и `scripts/security-gate.ps1`: внедрена функция `Get-ActiveSessionStepCount` — сверхбыстрый (160 мс) потоковый подсчет шагов активной сессии через `[System.IO.StreamReader]` без рекурсии.
  2. Добавлен красный тревожный баннер-стоппер при $\ge 180$ шагах, принудительно требующий запуска `prepare-handoff.ps1` и перехода в новый диалог.
  3. `SKILL.md`: добавлен Раздел 18 «Механический контроль контекстной гигиены».
  4. `CHANGELOG.md`: зафиксирован релиз v1.7.9.
- **Чекпоинт**: Релиз v1.7.9 (Mechanical Step Counter & Context Hygiene Guard).

### [2026-11-15 20:45]
- **Что сделано**: Внедрен комплекс стандартов мобильной разработки и инвариантов путей (Релиз v1.7.8):
  1. `scripts/security-gate.ps1`: внедрена проверка `PATH-001` (запрет кириллицы, не-ASCII символов и пробелов в путях для Android SDK, Gradle, Java, C/C++ и PyInstaller проектов).
  2. `SKILL.md`: добавлен Раздел 17 «Регламент мобильной разработки и реверс-инжиниринга APK (Android & Mobile Suite v1.7.8)»:
     - Запрет «слепого» дебага без живого `adb logcat`.
     - Защита Java SPI / ServiceLoader: обязательное сохранение `META-INF/services/` при сборке/перепаковке APK (предотвращение падений Paho MQTT / `NetworkModuleService`).
     - Визуальная фиксация интерфейса: обязательный `adb shell screencap` и `uiautomator dump` до обсуждения и правок UI.
     - Протокол устранения `SecurityException` при `adb shell input tap` через включение «Отладка по USB (Настройки безопасности)».
  3. `docs/ERRORS_AND_FAILURES.md`: зафиксирован инцидент краша Paho MQTT и падения `apktool` на кириллических путях.
  4. `CHANGELOG.md`: зафиксирован релиз v1.7.8.
- **Чекпоинт**: Релиз v1.7.8 (Android, Mobile & Path Invariants Suite).

### [2026-11-15 16:35]
- **Что сделано**: Внедрен стандарт Selective TDD by Default (Релиз v1.7.7):
  1. `SKILL.md`: добавлен Раздел 16 «Selective TDD by Default» — обязательный цикл RED $\rightarrow$ GREEN $\rightarrow$ REFACTOR для всей бизнес-логики, Telegram-ботов, бэкенда, API, баз данных, парсеров (OPDS) и вычислений.
  2. Зафиксированы четкие исключения без обязательного TDD (конфиги YAML/JSON/UCI, верстка, документация, косметические фиксы, аппаратный код без моков).
  3. В `Definition of Done` добавлен пункт 9: обязательное предоставление консольного лога прогона тестов с кодом завершения `0`.
  4. Создан `CHANGELOG.md` с фиксацией версионности проекта.
- **Чекпоинт**: Релиз v1.7.7 (Selective TDD by Default & Verification Gate).

### [2026-11-04 18:00]
- **Что сделано**: Устранена проблема создания базы ошибок `ERRORS_AND_FAILURES.md` в общей родительской папке:
  1. `record-failure.ps1`: внедрен трехуровневый алгоритм автоопределения подпроекта (по совпадению имен файлов `.py`/`.js`/`.sh` в тексте ошибки, по имени подпроекта и по незакоммиченным файлам Git), добавлен параметр `-SubProject`.
  2. Перенесен ошибочно созданный инцидент из корня `Router_Workspace` в `Router_Workspace/Opds/docs/ERRORS_AND_FAILURES.md`, пустая общая папка очищена.
  3. `SKILL.md`: обновлены разделы 3 и 14 с примерами вызова `record-failure.ps1` для подпроектов.
- **Чекпоинт**: Релиз v1.6.1 (Failure Log Subproject Auto-Isolation).

### [2026-11-04 17:00]
- **Что сделано**: Устранены все замечания масштабного код-ревью и реализован комплекс защиты для составных воркспейсов (Multi-Project Workspaces v1.6.0):
  1. `checkpoint.ps1`: порядок операций исправлен (обновление `PROJECT_STATE.md` выполняется ДО бэкапа и ДО git commit). Добавлено автоопределение активного подпроекта по изменениям Git, флаг `-SubProject`, а также автоматическое исключение вложенных подпроектов при сохранении родительского воркспейса (предотвращено создание 7-гигабайтных дубликатов).
  2. Регулярные выражения в `checkpoint.ps1` и `prepare-handoff.ps1` переведены на гибкий поиск `## (?:\d+\.\s*)?История Изменений` / `Стек Технологий` / `Следующие Шаги`, что восстановило полную совместимость с эталонным шаблоном `PROJECT_STATE_TEMPLATE.md`.
  3. `security-gate.ps1`: добавлена валидация синтаксиса PowerShell (`.ps1`) через AST-парсер, расширен поиск утечек учетных данных на `*.js`, `*.ts`, `*.json`, `*.php`, `*.cs`, реализовано изолированное сканирование подпроектов внутри Git-репозитория.
  4. `rollback.ps1`: сортировка точек отката переведена на строгое лексикографическое имя ISO, добавлен поиск и вывод предупреждения о новых неотслеживаемых файлах с рекомендацией `git clean -fd`.
  5. `install-skill.ps1`: хардкод `C:\Users\Salomanov` заменен на `$HOME`, добавлена поддержка `$env:GITHUB_TOKEN` для предотвращения блокировок GitHub API.
  6. `doctor.ps1`, `clean-backups.ps1`, `prepare-handoff.ps1`, `gen-env.ps1`: исправлены форматирование вывода `Write-Host`, кроссплатформенная фильтрация слешей и накопление стека.
  7. `SKILL.md`: исправлена нумерация разделов (9.1–9.6, Concurrency Gate 11), добавлен Раздел 14 «Работа в составных воркспейсах и монорепозиториях (Multi-Project Workspaces)».
- **Чекпоинт**: Релиз v1.6.0 (Multi-Project Workspace Protection & Stability Suite).

### [2026-10-30 00:35]
- **Что сделано**: Реализован комплекс утилит продуктивности (Productivity Suite v1.5.0):
  1. `doctor.ps1` — 1-кликовая диагностика рантаймов (Git, Python, Node), Git-синхронизации, целостности памяти и запуск Security Gate.
  2. `prepare-handoff.ps1` — генерация ультракомпактного слепка в `.agents/HANDOFF.md` и готового промпта для нового чата без сжигания токенов.
  3. `clean-backups.ps1` — безопасная ротация промежуточных чекпоинтов с гарантией неприкосновенности несгораемых релизов и поддержкой `-DryRun`.
  4. `gen-env.ps1` — автоматическое сканирование кодовой базы на вызовы переменных окружения и сборка безопасного шаблона `.env.example`.
  5. `checkpoint.ps1 -Verify` — опциональный предварительный запуск автотестов (`pytest`, `npm test`) перед фиксацией контрольной точки.
- **Чекпоинт**: Релиз v1.5.0 (Productivity Suite & Verification Gate).

### [2026-10-29 10:40]
- **Что сделано**: Внедрен Раздел 9 «Zero Exit Code 1 Discipline» с явной поддержкой нативного Git Bash (`C:\Program Files\Git\bin\bash.exe`) и Python UTF-8. Закреплен обязательный файловый запуск любых команд через `scratch/<task>.py` / `.sh`. Правило перенесено в глобальный `~/.gemini/config/AGENTS.md` для действия во всех сессиях.
- **Чекпоинт**: Релиз v1.4.0 (Zero Exit Code 1 Discipline & Git Bash Integration).

### [2026-10-29 18:00]
- **Что сделано**: Внедрён исполняемый security-gate по итогам `SKILL_REVIEW.md` (12 пунктов):
  раздел 8 переписан, добавлены Concurrency/Regression/DoD, `checkpoint.ps1` переведён на
  `-Push` по умолчанию выключен, шаблон памяти дополнен Product Goals и регрессиями.
- **Проверено**: гейт прогнан на `E:\Projects\Skill` и `E:\Projects\Router_api` — exit 0
  (исключения печатаются, см. `.security-gate-allow`).
- **Не проверено**: поведение `install-skill.ps1` и `rollback.ps1` на чистой машине.
- **Чекпоинт**: не создавался (по запросу владельца).
- 🛡️ **Чекпоинт** [2026-10-21 15:21:04] (метка: 2026-10-21_15-21-04): docs: update PROJECT_STATE with Rule 8 and record-failure

- 🛡️ **Чекпоинт** [2026-10-21 15:19:00] (метка: 2026-10-21_15-19-00): feat: add record-failure.ps1 for immediate failure and graphify logging

- 🛡️ **Чекпоинт** [2026-10-21 13:24:42] (метка: 2026-10-21_13-24-42): chore: update project path to E:\Projects\Skill
### [2026-10-21 13:25]
- **Что сделано**: Актуализирован и проверен путь проекта (`E:\Projects\Skill`). Проверена целостность Git и скриптов автоматизации. Путь на латинице полностью устраняет риски проблем с кодировкой в путях.
- **Чекпоинт**: Релиз v1.3.1 (Path update to E:\Projects\Skill).

### [2026-10-12 11:55]
- **Что сделано**: Интегрирован скилл и концепция `Ponytail` (борьба с оверинжинирингом, лаконичный код, запрет лишних внешних библиотек при наличии стандартных средств). Добавлено постоянное правило #7 в глобальный `AGENTS.md`.
- **Чекпоинт**: Релиз v1.3.0 (Ponytail Pragmatic Integration).

### [2026-09-28 15:00]
- **Что сделано**: Расширен функционал скилла до универсального стандарта (Web + Desktop + Firmware). Добавлено автоопределение категории проекта, сохранение десктопных бинарников (`.exe`, `.msi`), веб-сборок (`dist/`) и режим `-List` в откат.
- **Чекпоинт**: Релиз v1.2.0 (Universal Multi-Domain).

### [2026-09-23 10:55]
- **Что сделано**: Добавлена поддержка создания отдельных изолированных бэкапов при каждой удачной прошивке (`-Firmware`).
- **Чекпоинт**: Релиз v1.1.0 с поддержкой прошивок.

### [2026-09-23 10:30]
- **Что сделано**: Первоначальный релиз скилла `project-guardian`.

