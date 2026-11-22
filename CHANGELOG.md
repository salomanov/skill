# Changelog

All notable changes to Project Guardian are documented in this file.

## v2.1.0 - 2026-11-22

### Added
- **Интеграция архитектурных принципов Harness² (Google Research, Recursive Agent Harnessing)**:
  - **Зондирование скиллов (`scripts/probe-skill.ps1`, команда `guardian.ps1 probe` / `prb`)**:
    - Валидация структуры `SKILL.md` (YAML frontmatter: `name`, `description`).
    - Проверка кодировки UTF-8 и целостности файлов.
    - AST-анализ синтаксиса PowerShell (`.ps1`) и компиляция Python (`.py`).
    - Детекция отсутствия UTF-8 BOM в Shell-скриптах (`.sh`) для совместимости с Linux/Android.
    - Детекция несовместимых с Windows команд Linux (`sudo`, `apt-get`, `yum`, `brew`).
    - Проверка утечек секретов и приватных ключей.
  - **Probe Gate в установщике скиллов (`scripts/install-skill.ps1`)**:
    - Автоматический пробинг скилла перед сохранением в `~/.gemini/config/skills/`.
    - Блокировка поврежденных или несовместимых скиллов (обход через `-Force`).
  - **Комплексный аудит 8 измерений обвязки (`scripts/audit-harness.ps1`, `guardian.ps1 harness` / `hrn`, `doctor.ps1 -Harness`)**:
    - Анализ всех 8 измерений: System Prompts, Tools, Memory, Guardrails, Scripts, Skills, Subagents, Control Hooks.
    - Единый сводный дашборд здоровья обвязки агента (8/8 Dimensions Operational).
  - **Расширение TDD-сьюта (`tests/test_guardian.py`)**:
    - Тесты `test_guardian_harness_audit`, `test_guardian_probe_self`, `test_guardian_probe_invalid_dir` (9/9 PASSED).
  - **Документация**:
    - Раздел 21 в `SKILL.md` («Интеграция с принципами Harness²: Зондирование и 8 Измерений Обвязки»).
    - Обновление фасада CLI `guardian.ps1` до v2.1 (16 команд).

---

## v2.0.1 - 2026-11-22

### Fixed
- **Targeted Skill Recommendation Routing (`scripts/add-recommendation.ps1`, `scripts/record-failure.ps1`)**:
  - Устранена архитектурная ошибка, когда все рекомендации при вызове `-ToSkill` или пустом `-TargetProject` слепо сбрасывались в ядро `Skill` (Project Guardian).
  - Внедрен параметр `-Skill <SkillName>` (алиас `-SkillName`) с авто-поиском папки скилла в `~/.gemini/config/skills/<SkillName>` и локальных каталогах воркспейса.
  - Запрещен нецелевой сброс: вызов `add-recommendation.ps1` без указания `-Skill` или `-TargetProject` завершается с понятной ошибкой и примерами.
  - Параметр `-RecommendToSkill` в `record-failure.ps1` переведен на поддержку имени скилла.
  - Раздел 13 `SKILL.md` дополнен четким протоколом адресации (мета-правила для Guardian vs предметные правила для доменных скиллов).
  - Добавлен тест в `tests/test_guardian.py` (6/6 PASSED).
  - Ошибочная рекомендация Usque перенаправлена в `router-ops` и заархивирована в `docs/APPLIED_RECOMMENDATIONS.md`.

---

## v2.0.0 - 2026-11-21

### Added
- **Project Guardian CLI v2.0 Facade (`guardian.ps1`, `scripts/guardian.ps1`)**:
  - Единая консольная точка входа, консолидирующая все утилиты Guardian: `checkpoint` (`cp`), `doctor` (`doc`), `gate` (`security`, `sec`), `test` (`tests`), `rollback` (`rb`), `failure` (`record`, `fail`), `handoff`, `scratch`, `clean`, `env`, `install`, `check-skills`, `recommend`, `email`.
  - Автоматическое многоуровневое определение расположения каталога `scripts/` (относительно вызываемого скрипта, git root, глобального скилла и CWD).
  - Безопасный сплэттинг аргументов PowerShell 5.1 (предотвращает затирание значений по умолчанию пустыми строками при вызовах без аргументов).
  - Информативная справка `--help` с группировкой команд, подсветкой синтаксиса и практическими примерами.
  - Набор модульных тестов `tests/test_guardian.py` (верификация корневого и скриптового входов, парсинга команд, кода возврата и Security Gate).
- **Раздел 20 в `SKILL.md`**: спецификация фасада CLI, таблица команд и регламент вызовов.

---

## v1.8.1 - 2026-11-21

### Added
- **Auto-Ensure Test Runner (`scripts/run-tests.ps1`)**:
  - Автоматическая проверка наличия `pytest` с самовосстановлением через `uv pip install` / `pip install`.
  - Безопасный фоллбэк на встроенный `python -m unittest discover` при отсутствии pytest.
  - Поддержка запуска `npm test` для проектов с `package.json`.
  - Интеграция в фасад и тесты TDD.

---

## v1.8.0 - 2026-11-20

### Added
- **Auto-Graphify Initialization & PowerShell 5.1 Reliability (`scripts/checkpoint.ps1`)**:
  - Устранена ловушка `if (Test-Path $graphifyDir)`: теперь `checkpoint.ps1` автоматически инициализирует `graphify-out/` (`graphify extract --code-only`) при первом чекпоинте, если графа ещё нет, и обновляет через `graphify update`, если он уже существует.
  - Временное переключение `$ErrorActionPreference = "Continue"` вокруг вызова `python -m graphify` исключает ложный крах `NativeCommandError` на выводе `stderr` в Windows PowerShell 5.1.
  - Автоматическая генерация `.graphifyignore` и добавление `.backups/` / `scratch/` в `.gitignore` выполняются ДО запуска Graphify.
- **Dialog Title Preservation (`scripts/get_dialog_title.py`, `prepare-handoff.ps1`, `checkpoint.ps1`)**:
  - `prepare-handoff.ps1` автоматически считывает название текущего диалога из `conversation_summaries.db` (или наследует из `.agents/HANDOFF.md`) и подставляет `Тема диалога: <Title>` первой строкой промпта.
  - `checkpoint.ps1` автоматически восстанавливает чистое название нового диалога в `conversation_summaries.db`, если оно было сгенерировано как техническое.
- **Failure & Recommendation Executable Guardrails (`scripts/add-recommendation.ps1`, `record-failure.ps1`, `security-gate.ps1`, `doctor.ps1`)**:
  - Создан генератор межпроектных рекомендаций `scripts/add-recommendation.ps1` (поддерживает `-ToSkill`).
  - В `record-failure.ps1` добавлены флаги `-RecommendToSkill` и `-RecommendToProject`.
  - В `checkpoint.ps1` внедрены `FAIL-GUARD` (контроль обновления `docs/ERRORS_AND_FAILURES.md` при багфиксах), `REC-GUARD` (напоминание об открытых рекомендациях) и `Auto-Git-Init` (автоматический `git init` для одиночных проектов без `.git`).
  - В `security-gate.ps1` внедрены проверки `REC-001` (запрет неархивированных `[x] ВЫПОЛНЕНО` в `AGENT_RECOMMENDATIONS.md`) и `SYNTAX-BOM` (запрет UTF-8 BOM в Linux `.sh`/`S9*` и Android `.kl`/`.idc`).
  - В `doctor.ps1` добавлена диагностика `docs/ERRORS_AND_FAILURES.md` и `AGENT_RECOMMENDATIONS.md`.
- **Новые инженерные инварианты в `SKILL.md` (Раздел 10.11–10.14)**:
  - Быстрый поиск без зависаний на `.backups` (`graphify` / `git ls-files`).
  - Защита от коллизии `PROCS=python3` в Entware `rc.func`.
  - Именованные сырые строки C++ (`R"rawhtml(...)rawhtml"`) и безопасный поиск ключей JSON.
  - Правило UTF-8 BOM vs No-BOM и Single Source of Truth при патчинге бандлов/APK.

### Fixed
- Исправлен баг `` `	ext `` (превращение `` `t `` в табуляцию внутри `@"..."@`) в `prepare-handoff.ps1`.
- Исправлен парсинг `$recentChanges` в `prepare-handoff.ps1` (извлекается суть последнего чекпоинта, а не голая дата).
- Закрыты и перенесены в `docs/APPLIED_RECOMMENDATIONS.md` все открытые рекомендации из `AGENT_RECOMMENDATIONS.md`.

---

## v1.7.11 - 2026-11-18

### Added
- **Universal Email Dispatcher (Раздел 19 в SKILL.md)**:
  - Глобальный скрипт отправки почты `scripts/send-email.py` и PowerShell-обертка `scripts/send-email.ps1`.
  - Поддержка вложений любого типа (файлы, картинки, архивы, EPUB/PDF, логи), SSL/TLS порт 465 (Mail.ru SMTP), кириллических имен файлов.
  - Безопасная конфигурация в `~/.gemini/config/email_settings.json` (адрес получателя по умолчанию: `salomanov@ya.ru`, отправитель: `salomanov@list.ru`).
  - Поведенческие триггеры в `SKILL.md`: автоматическая отправка по фразам *«напиши мне на почту»*, *«скинь мне на почту»*, *«отправь на email»* без лишних переспросов адреса.

### Changed
- `PROJECT_STATE.md` обновлен до версии 1.7.11.

---

## v1.7.10 - 2026-11-15

### Fixed
- **Targeted Session Step Counter & False Alert Prevention**:
  - Устранено ложное срабатывание счетчика шагов: вместо слепого перебора директорий `brain` по `LastWriteTime`, определение текущей сессии переведено на нативную переменную `$env:ANTIGRAVITY_CONVERSATION_ID` и параметр `-ConversationId`.
  - Новый диалог (например, `0d7841b1`) больше никогда не перехватит 2000+ шагов из предыдущего закрытого диалога (`236ded68`).

### Changed
- `PROJECT_STATE.md` обновлен до версии 1.7.10.

---

## v1.7.9 - 2026-11-15

### Added
- **Mechanical Step Counter & Context Hygiene Guard (Раздел 18 в SKILL.md)**:
  - Функция `Get-ActiveSessionStepCount` в `scripts/checkpoint.ps1` и `scripts/security-gate.ps1`: быстрый потоковый подсчет шагов активной сессии через `[System.IO.StreamReader]`.
  - Красный стоп-баннер при $\ge 180$ шагах с принудительным требованием запуска `prepare-handoff.ps1` и перехода в новый диалог.
  - Аппаратная защита от когнитивной деградации моделей на сверхдлинных сессиях.

### Changed
- `PROJECT_STATE.md` обновлен до версии 1.7.9 и статуса `Mechanical Step Counter Enforced`.

---

## v1.7.8 - 2026-11-15

### Added
- **Android, Mobile & Path Invariants Suite (Раздел 17 в SKILL.md)**:
  - Проверка `PATH-001` в `scripts/security-gate.ps1`: автоматический запрет кириллицы, не-ASCII символов и пробелов в путях для проектов Android, Java, Kotlin, C/C++ и PyInstaller.
  - Регламент мобильной разработки: категорический запрет слепой отладки без живого `adb logcat`.
  - Защита Java SPI: обязательное сохранение каталога `META-INF/services/` при сборке/модификации APK (предотвращение падений Paho MQTT / `NetworkModuleService`).
  - Протокол UI: обязательная фиксация экрана через `adb shell screencap` и `uiautomator dump` до обсуждения и правок интерфейса.
  - Чеклист по `SecurityException`: оперативное устранение ошибки прав `adb shell input tap` через включение «Отладка по USB (Настройки безопасности)» в настройках Android.
- База ошибок: создан `docs/ERRORS_AND_FAILURES.md` с фиксацией инцидента Paho MQTT и кириллических путей.

### Changed
- `PROJECT_STATE.md` обновлен до версии 1.7.8 и статуса `Mobile & Path Invariants Enforced`.

---

## v1.7.7 - 2026-11-15

### Added
- **Selective TDD by Default (Раздел 16 в SKILL.md)**:
  - Автоматический обязательный цикл TDD (RED $\rightarrow$ GREEN $\rightarrow$ REFACTOR) для всей бизнес-логики, бэкенда, Telegram-ботов (хэндлеры, состояния, карточки), API, баз данных, парсеров (включая OPDS) и алгоритмов.
  - Точный перечень исключений, не требующих TDD: конфигурационные файлы, верстка/стили, документация, косметические однострочники и низкоуровневый аппаратный код без моков.
  - Запрет сдачи задачи (Gate сдачи) без фактического терминального лога прогона тестов со статусом `PASSED` и кодом `exit 0`.
- Пункт 9 в Definition of Done: обязательное подтверждение тестами перед закрытием задачи.

### Changed
- `PROJECT_STATE.md` обновлен до версии 1.7.7 и статуса `Selective TDD by Default enforced`.

---

## v1.7.6 - 2026-11-14
- Синхронизация репозиториев и источников скиллов: классификация `ponytail` (DietrichGebert/ponytail) и `rea` (morluto/rea).
- Установка официальных скиллов `telegram` и `telegram-bot-builder`.

## v1.7.5 - 2026-11-14
- Автоматический аудит версий сторонних пакетов и инструментов (`graphifyy`, `playwright`, `tinytuya`, `pyinstaller`).

## v1.7.4 - 2026-11-14
- Реализация монитора новых скиллов `scripts/check-new-skills.ps1` для каталога `sickn33/agentic-awesome-skills`.

## v1.7.3 - 2026-11-14
- Политика актуальности скиллов (Skill and Tool Freshness Policy) с поддержкой флагов `-CheckOnly` и `-Update` в `install-skill.ps1`.

## v1.7.2 - 2026-11-14
- Жизненный цикл рекомендаций и архив `docs/APPLIED_RECOMMENDATIONS.md`.

## v1.6.0 - 2026-10-31
- Multi-Project Workspace Protection & Stability Suite (изоляция подпроектов, предотвращение дублирования бэкапов).
