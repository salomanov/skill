# Состояние Проекта: Project Guardian (Universal Skill)

> Данный файл автоматически ведется агентом и служит долговременной памятью проекта.
> При начале новой сессии агент считывает этот файл в первую очередь.

- **Версия**: `v2.3.0` (Honest Harness, Context Hygiene & Modular Skill Suite)
- **Статус**: Активен, 28/28 Behavioral Tests PASSED, Honest Harness, Modular SKILL & Memory Rotated
- **Дата обновления**: 2026-11-22


---

## 1. Описание и Назначение
- **Тип проекта**: 🛡️ Универсальный скилл и комплекс автономных правил для Antigravity
- **Текущее расположение**: `E:\Projects\Skill`
- **Целевые сферы**: 
  - 🌐 Веб-сайты и веб-сервисы (Frontend / Backend / Fullstack)
  - 🖥️ Программы для ПК (Desktop GUI, PyInstaller, C#, Electron)
  - 🔥 Прошивки микроконтроллеров (ARM Cortex, STM32, ESP32)
- **Цель проекта**: Полная автоматизация рутины: долговременная память (`PROJECT_STATE.md`), несгораемые архивы сборок и прошивок с датой и временем, безопасный откат, авто-коммит в Git (пуш — только по явному `-Push`), автономная установка скиллов, архитектурный анализ через Graphify, исполняемый security-gate, интеграция принципов Ponytail и изолированная защита в составных воркспейсах/монорепозиториях.
- **Репозиторий**: https://github.com/salomanov/skill.git

## 1a. Product Goals (не менять без владельца)
1. Агент не повторяет уже исправленные ошибки: правила скилла проверяются **исполняемым** гейтом, а не галочками.
2. Проект не теряет контекст между сессиями и не откатывается молча: память, чекпоинты, регрессии.
3. Ничего не уезжает в remote без явного решения владельца.
4. В составных воркспейсах (монорепозиториях) чекпоинты и фиксация ошибок создаются изолированно для целевого подпроекта, без раздувания родительской папки гигабайтными дубликатами.

## 2. Стек Технологий и Инструменты
- **Рантайм и шелл**: PowerShell 5.1+ / Windows
- **Платформа**: Google Antigravity / Gemini CLI
- **Интеграции**: Git, GitHub REST API, Graphify, Agentic Awesome Skills Catalog, Ponytail

## 3. Архитектура и Структура Репозитория
```text
/
├── guardian.ps1                      # Единый консольный фасад CLI Project Guardian
├── SKILL.md                          # Универсальный манифест скилла
├── scripts/
│   ├── guardian.ps1                  # Идентичный фасад CLI внутри каталога скриптов
│   ├── checkpoint.ps1                # Чекпоинты, бэкапы веб-релизов, десктоп-сборок (.exe), прошивок (-SubProject, -Verify)
│   ├── doctor.ps1                    # Экспресс-диагностика окружения, рантаймов, Git и подпроектов
│   ├── run-tests.ps1                 # Авто-раннер тестов с Auto-Ensure (pytest/unittest/npm)
│   ├── prepare-handoff.ps1           # Генерация ультракомпактного контекста (.agents/HANDOFF.md)
│   ├── clean-backups.ps1             # Безопасная ротация промежуточных бэкапов (-DryRun)
│   ├── gen-env.ps1                   # Сканер кодовой базы и генератор шаблона .env.example
│   ├── security-gate.ps1             # Исполняемый гейт: секреты, антипаттерны, синтаксис Python/Node/Bash/PS1 (exit 1)
│   ├── record-failure.ps1            # Фиксация инцидентов в docs/ERRORS_AND_FAILURES.md (-SubProject, автоопределение)
│   ├── rollback.ps1                  # Менеджер отката с просмотром точек (-List) и детекцией новых файлов
│   ├── new-scratch.ps1               # Безопасный генератор scratch-скриптов (UTF-8, авто-подтягивание SSH/API кредов)
│   ├── install-skill.ps1             # Автономный загрузчик скиллов из GitHub (с Probe Gate и $HOME)
│   ├── check-new-skills.ps1          # Сканер свежих поступлений скиллов в апстриме
│   ├── probe-skill.ps1               # Зондирование скиллов (Harness² Probe: YAML, UTF-8, AST, OS portability)
│   ├── audit-harness.ps1             # Комплексный аудит 8 измерений обвязки агента (Harness² Audit)
│   ├── add-recommendation.ps1        # Генератор рекомендаций для внешних проектов
│   └── send-email.ps1                # Универсальный почтовый шлюз (SSL/TLS, вложения)
├── tests/
│   └── test_guardian.py              # Автотесты фасада guardian.ps1 (pytest/unittest)
├── references/
│   └── PROJECT_STATE_TEMPLATE.md     # Универсальный шаблон памяти проекта
├── .gitignore
├── PROJECT_STATE.md                  # Память проекта
├── CHANGELOG.md
└── README.md
```

## 4. Текущий Статус и Реализованный Функционал
- [x] Реализована универсальная поддержка: Веб-сайты, ПК-программы, Прошивки
- [x] Автоопределение типа проекта в `checkpoint.ps1`
- [x] Несгораемые архивы релизов без перезаписи: `.exe` / бинарники / веб-дистрибутивы
- [x] Паспорта сборки `RELEASE_INFO.md` / `FIRMWARE_INFO.md` с хэшами SHA256
- [x] Режим просмотра списка точек восстановления `rollback.ps1 -List`
- [x] Интеграция Ponytail (режим «ленивого сеньора», экономия токенов и кода на 50%+)
- [x] Обновлены глобальные правила в `~/.gemini/config/AGENTS.md` (Правило #7: Ponytail, Правило #8: Immediate Failure & Graphify Logging)
- [x] Создан скрипт `record-failure.ps1` для моментального логирования инцидентов, запуска graphify и Git авто-коммита
- [x] Подключен удаленный репозиторий `https://github.com/salomanov/skill.git`
- [x] Проект перенесен в `E:\Projects\Skill`
- [x] **v1.4.0**: исполняемый `scripts/security-gate.ps1` (секреты, `| sh`, `shell=True`, `auth.enabled=false`, `verify=False`, `python3 -c`, `chmod 777`, wildcard CORS, синтаксис) + `.security-gate-allow` с причинами
- [x] **v1.4.0**: раздел 8 переписан (запрет дефолтных кредов и fallback-аутентификации, запрет отключать защиту ради UX), добавлены Concurrency Gate, Regression Gate, Definition of Done
- [x] **v1.4.0**: `checkpoint.ps1` больше не пушит по умолчанию (`-Push` — явный флаг), `record-failure.ps1` коммитит локально
- [x] **v1.4.0**: в шаблон `PROJECT_STATE_TEMPLATE.md` добавлены Product Goals, Non-goals, Regressions, Осознанные исключения
- [x] **v1.5.0**: Productivity Suite: `doctor.ps1` (диагностика окружения), `prepare-handoff.ps1` (передача контекста в новый диалог), `clean-backups.ps1` (ротация бэкапов), `gen-env.ps1` (генератор `.env.example`), флаг `-Verify` в `checkpoint.ps1`
- [x] **v1.6.0**: Multi-Project Workspace Protection & Bugfix Suite:
  - Решена проблема раздувания бэкапов в составных воркспейсах (монорепозиториях): автоопределение активного подпроекта по Git, поддержка `-SubProject` / `-ProjectPath`, исключение вложенных проектов при бэкапе корня воркспейса.
  - В `record-failure.ps1` добавлено интеллектуальное автоопределение подпроекта (по совпадению имен файлов `.py`/`.js`, тексту ошибки и изменениям Git) и флаг `-SubProject` для предотвращения записи ошибок в корень общего воркспейса.
  - Исправлен порядок операций в `checkpoint.ps1`: `PROJECT_STATE.md` обновляется ДО создания бэкапа и ДО git commit (устранен грязный git status).
  - Устранена жесткая привязка к номерам разделов в регулярных выражениях (`## (?:\d+\.\s*)?История Изменений`, `Стек Технологий`, `Следующие Шаги`).
  - Добавлена AST-проверка синтаксиса `.ps1` файлов в `security-gate.ps1` и поддержка изолированного сканирования подпроектов.
  - В `rollback.ps1` добавлена строгая хронологическая сортировка по именам папок и проверка появившихся неотслеживаемых файлов.
  - В `install-skill.ps1` устранен хардкод путей (переход на `$HOME`) и добавлена поддержка GitHub API токенов.
  - Устранены ошибки нумерации разделов в `SKILL.md` (9.1–9.6, Concurrency Gate 11, Добавлен раздел 14).
- [x] **v1.6.2**: Рекомендации AGENT_RECOMMENDATIONS (Windows CLI UTF-8 & Firmware Checkpoint Separation):
  - Во всех `.ps1` скриптах внедрена установка `$env:PYTHONIOENCODING = "utf-8"`, `[Console]::OutputEncoding = UTF8` и гарантирован UTF-8 BOM.
  - В `checkpoint.ps1` проекты микроконтроллеров разделены на промежуточные чекпоинты (`checkpoint_firmware_*`) и несгораемые релизные прошивки (`firmware_success_*`, только с флагом `-Firmware` или `-Release`).
  - В `rollback.ps1` и `doctor.ps1` добавлено распознавание `checkpoint_firmware_*`.
  - В `SKILL.md` (раздел 10.2) и `PROJECT_STATE_TEMPLATE.md` внесены правила запуска PlatformIO (`$env:PYTHONIOENCODING='utf-8'; pio run`).
- [x] **v1.6.3**: Рекомендации AGENT_RECOMMENDATIONS (Zero Exit Code 1: Read Credentials First, Targeted Tests, Robust Argument Parsing):
  - В `SKILL.md` (10.6, 10.7) и глобальные правила `AGENTS.md` внедрены правила «Read Credentials & Config First» и «Targeted Test Discovery».
  - В `checkpoint.ps1`, `record-failure.ps1` и `prepare-handoff.ps1` добавлена защита от неэкранированных пробелов в аргументах (`ValueFromRemainingArguments` + авто-склейка строк).
  - Скрипты сохранены с UTF-8 BOM, пройден гейт безопасности.
- [x] **v1.7.0**: Executable Barriers & Stability Suite:
  - Создан генератор `scripts/new-scratch.ps1` с автоподстановкой UTF-8 и параметров SSH/API из проекта.
  - В `AGENTS.md` и `SKILL.md` внедрен жесткий запрет циклического поллинга Delegator (`No-Polling & Reactive Stop`).
  - В Rule 0 зафиксирован норматив контекстной гигиены: при 150–200 шагах обязательна передача контекста через `prepare-handoff.ps1`.
- [x] **v1.7.1**: Рекомендации AGENT_RECOMMENDATIONS (WildcardPatternException Fix & Windows CRLF):
  - В `security-gate.ps1` вызовы `Test-Path` переведены на `-LiteralPath` для исключения краха `WildcardPatternException` на файлах с квадратными скобками (`log (2).txt`, `[id].tsx`).
  - В `new-scratch.ps1` добавлена подсказка-напоминание по работе с Dropbear SSH (запрет `open_sftp()`, передача через `cat > path`).
  - В `SKILL.md` (разделы 10.9, 10.10) и `AGENTS.md` добавлены правила по Windows CRLF vs LF для `edit_file` и безопасному использованию `-LiteralPath`.

- [x] **v1.8.1**: Auto-Ensure Test Runner (`scripts/run-tests.ps1`) с автоустановкой `pytest` и фоллбэком на `unittest discover`.
- [x] **v2.0.0**: Consolidation Suite — Единый CLI-фасад `guardian.ps1` (в корне и в `scripts/guardian.ps1`):
  - Консолидация всех утилит проекта в единую команду с поддержкой алиасов (`checkpoint|cp`, `doctor|doc`, `gate|security|sec`, `test|tests`, `rollback|rb`, `failure|record|fail`, `handoff`, `scratch`, `clean`, `env`, `install`, `check-skills`, `recommend`, `email`).
  - Интеллектуальное многоуровневое авто-определение путей каталога `scripts/` (рядом со скриптом, в скриптовой директории, в git root, в глобальном скилле и в CWD).
  - Защищенный от пустых строк сплэттинг аргументов в PowerShell 5.1 (сохранение дефолтных значений скриптов).
  - Модульные тесты `tests/test_guardian.py` (5/5 PASSED в pytest через `run-tests.ps1`).
  - Раздел 20 в `SKILL.md` и обновление документации.
- [x] **v2.0.1**: Targeted Skill Recommendation Routing & Usque Archive:
  - Внедрен параметр `-Skill <SkillName>` в `add-recommendation.ps1` и `record-failure.ps1` с авто-резолвом путей в `~/.gemini/config/skills/<SkillName>`.
  - Запрещен слепой сброс рекомендаций в ядро `Skill` при отсутствии целевого проекта.
  - Актуализирован Раздел 13 в `SKILL.md` и справка `guardian.ps1 recommend`.
  - Добавлен 6-й автотест в `tests/test_guardian.py` (проверка валидации адресата рекомендации).
  - Ошибочно направленная рекомендация по вотчдогу Usque перенаправлена в `router-ops` и заархивирована в `docs/APPLIED_RECOMMENDATIONS.md`.
- [x] **v2.1.0**: Harness² Recursive Scaffolding & Skill Probe Integration:
  - Разработан скрипт `scripts/probe-skill.ps1` (валидация структуры `SKILL.md`, YAML frontmatter, UTF-8, синтаксиса `.ps1`/`.py`/`.sh` и детекция несовместимых команд Linux).
  - Внедрен Probe Gate в `scripts/install-skill.ps1` (автоматическое зондирование скилла перед установкой в `~/.gemini/config/skills/`, блокировка с флагом `-Force`).
  - Разработан аудит 8 измерений обвязки `scripts/audit-harness.ps1` (`guardian.ps1 harness` / `doctor.ps1 -Harness`).
  - Добавлены команды `probe` (алиас `prb`) и `harness` (алиас `hrn`) в `guardian.ps1` CLI (в корне и в `scripts/`).
  - TDD-тесты `tests/test_guardian.py` расширены до 9 тестов (9/9 PASSED).
  - Манифест `SKILL.md` дополнен Разделом 21.
- [x] **v2.2.0**: Production Hardening & Honest Scaffolding Suite (по итогам независимого аудита):
  - Починен счетчик шагов сессии `session-guard.ps1` (парсинг `step_index` в JSONL, эвристика пути проекта, тихий возврат 0 при неизвестной сессии).
  - В `security-gate.ps1` внедрено исполняемое правило `PS-001` (проверка `Test-Path` с `-LiteralPath`).
  - Усилен формат `.security-gate-allow`: привязка к правилу, файлу и номеру строки (`RULE-ID path[:line] # reason`), удалены широкие подстроки и персональные email.
  - Устранено дублирование CLI: корневой `guardian.ps1` переведен на тонкий шим к `scripts/guardian.ps1`.
  - Поведенческий TDD-сьют `tests/test_guardian.py` расширен с 9 до 26 автотестов (26/26 PASSED): раундтрип `checkpoint`/`rollback`, probe gate в `install-skill`, `session-guard`.
  - В `.gitignore` добавлены `ses_*.json` и `*.transcript.json`.

## 4a. Известные исправления (Regressions — не сломать повторно)
1. Раздел 8/9 не должен снова разрешать «пароль по умолчанию» — именно эта формулировка легализовала бэкдор.
2. `checkpoint.ps1` не должен пушить без `-Push`: серия неудачных правок уезжала в remote.
3. Правила без исполняемой проверки нарушаются — новое правило добавляется вместе с проверкой в гейте.
4. `checkpoint.ps1` обязан обновлять `PROJECT_STATE.md` ДО снятия снимка бэкапа и ДО git commit, иначе рабочее дерево остается грязным, а архив не содержит актуального лога.
5. Скрипты Guardian обязаны изолировать подпроекты в составных воркспейсах (`-ProjectPath`, `-SubProject`), чтобы исключить дублирование родительских папок и гигабайтный оверхед.
6. Регулярные выражения для заголовков `PROJECT_STATE.md` не должны привязываться к жесткому номеру раздела (поддержка `## (?:\d+\.\s*)?`).
7. `record-failure.ps1` обязан изолировать запись `docs/ERRORS_AND_FAILURES.md` в целевой подпроект в составных воркспейсах.
8. CLI утилиты на Python (PlatformIO `pio`, `esptool`, `pip`, `uv`, `graphify`) в русской Windows обязаны запускаться с `$env:PYTHONIOENCODING = "utf-8"` и `[Console]::OutputEncoding = UTF8`, иначе падают с крахом `charmap cp1251 UnicodeEncodeError`.
9. В `checkpoint.ps1` категория `Firmware` не должна безусловно выставлять `$Release = $true`: обычные чекпоинты кода и сбои создают `checkpoint_firmware_*`, а релиз с паспортом и тегом создается только по явному флагу `-Release` / `-Firmware`.
10. Запрещено угадывать учетные данные (логины, пароли, порты) при создании scratch-скриптов; параметры обязаны предварительно считываться из конфигураций и `deploy.py`.
11. Запрещен неявный запуск unittest/pytest `discover()` в корне составного воркспейса во избежание исполнения внутренних тестов пакетов из `site-packages`.
12. Параметры сообщений в скриптах (`-Message`, `-Title`, `-NextGoal`) обязаны поддерживать неэкранированные пробелы и несколько позиционных аргументов (`ValueFromRemainingArguments`) во избежание сбоев парсера PowerShell.
13. Запрещен циклический поллинг задач Delegator (`manage_task`/`sleep.py`) при уходе в фон: агент обязан отправить одно сообщение и завершить ход.
14. Для создания scratch-скриптов использовать генератор `new-scratch.ps1`, исключающий пропуск `sys.stdout.reconfigure` и кредов.
15. При достижении диалогом 150–200 шагов обязательна передача контекста через `prepare-handoff.ps1` во избежание когнитивной деградации.
16. В вызовах `Test-Path` на файлах проекта обязательно использовать `-LiteralPath` во избежание краха `WildcardPatternException` на путях с квадратными скобками (`[id]`, `log (2).txt`).
17. В `checkpoint.ps1` запуск `graphify` не должен блокироваться условием `if (Test-Path $graphifyDir)` и обязан выполняться с `$ErrorActionPreference = "Continue"` ПОСЛЕ добавления `.backups/` в `.gitignore` и `.graphifyignore` (иначе PowerShell 5.1 обрывает `python -m graphify` на `stderr`, а новые проекты остаются без графа).
18. В `prepare-handoff.ps1` запрещено писать ```` ```text ```` внутри двойного here-string `@"..."@` (иначе `` `t `` превращается в символ табуляции `` `	ext ``); название диалога обязано извлекаться из `conversation_summaries.db` и сохраняться в `.agents/HANDOFF.md`.
19. Linux shell-скрипты (`.sh`, `S9*`) и Android KeyLayout (`.kl`, `.idc`) обязаны сохраняться строго в UTF-8 без BOM (проверяется правилом `SYNTAX-BOM` в `security-gate.ps1`), а выполненные рекомендации `[x] ВЫПОЛНЕНО` обязаны архивироваться в `docs/APPLIED_RECOMMENDATIONS.md` (правило `REC-001`).
20. В `guardian.ps1` вызов целевых скриптов обязан явно разделять ветку `$RestArgs.Count -gt 0` (вызов с аргументами) и ветку без аргументов: в противном случае сплэттинг пустого массива `@RestArgs` в PowerShell 5.1 приводит к передаче пустой строки `""` в первый позиционный параметр и затиранию параметров со значениями по умолчанию (например, `$ProjectPath = (Get-Location).Path`).
21. Рекомендации межпроектного взаимодействия обязаны адресоваться целевому скиллу (`-Skill <Name>`) или проекту (`-TargetProject <Path>`), а не сбрасываться по умолчанию в ядро Project Guardian (`Skill`), во избежание засорения мета-скилла специфичными доменными правилами (роутеры, электроника, книги).
22. В `doctor.ps1` параметры обязаны оформляться с `[CmdletBinding()]` и валидацией `$ProjectPath.StartsWith("-")`, чтобы флаги вроде `-Harness` не затирали путь к проекту по позиционному сопоставлению.

## 5. История Изменений

- 🛡️ **Чекпоинт** [2026-11-22 17:55:01] (метка: 2026-11-22_17-55-01): v2.3.1: Step counter threshold calibration (500 steps, user/model/trajectory differentiation)

- 🛡️ **Чекпоинт** [2026-11-22 17:45:56] (метка: 2026-11-22_17-45-56): v2.3.0: Honest Harness, Context Hygiene and Modular Skill Suite

> 📜 **Архив изменений**: Полная история чекпоинтов и релизов версий v1.1.0 – v1.8.1 архивирована в [docs/HISTORICAL_STATES.md](docs/HISTORICAL_STATES.md).

- 🛡️ **Чекпоинт** [2026-11-22 17:32:37] (метка: 2026-11-22_17-32-37): pre-v2.3.0: Honest Harness and Context Hygiene

- 🛡️ **Чекпоинт** [2026-11-22 17:20:02] (метка: 2026-11-22_17-20-02): v2.2.0: Production Hardening & Honest Scaffolding Suite

- 🛡️ **Чекпоинт** [2026-11-22 12:20:50] (метка: 2026-11-22_12-20-50): v2.1.0: Harness2 Integration (Probe Gate & 8 Dimensions Audit)

- 🛡️ **Чекпоинт** [2026-11-22 12:14:01] (метка: 2026-11-22_12-14-01): pre-v2.1.0: Harness2 Integration

- 🛡️ **Чекпоинт** [2026-11-22 01:40:33] (метка: 2026-11-22_01-40-33): v2.0.1 Targeted Skill Recommendation Routing & Usque Archive

- 🛡️ **Чекпоинт** [2026-11-22 01:36:09] (метка: 2026-11-22_01-36-09): failure: Ложная маршрутизация рекомендаций в ядро Guardian вместо доменных скиллов

- 🛡️ **Чекпоинт** [2026-11-22 01:35:59] (метка: 2026-11-22_01-35-59): pre-fix: targeted skill recommendation routing

- 🛡️ **Чекпоинт** [2026-11-21 21:00:25] (метка: 2026-11-21_21-00-25): v2.0.0 Final Consolidation & Global Installation Sync

- 🛡️ **Чекпоинт** [2026-11-21 20:53:26] (метка: 2026-11-21_20-53-26): v2.0.0 RestArgs array typing fix

- 🛡️ **Чекпоинт** [2026-11-21 20:50:27] (метка: 2026-11-21_20-50-27): v 2 . 0 . 0   P r o j e c t   G u a r d i a n   C o n s o l i d a t i o n   C L I   F a c a d e   a n d   T D D   S u i t e

- 🛡️ **Чекпоинт** [2026-11-21 20:37:59] (метка: 2026-11-21_20-37-59): Pre-v2.0 Consolidation guardian facade


### [2026-11-22 17:20]
- **Что сделано**: Релиз **v2.2.0** (Production Hardening & Honest Scaffolding Suite):
  1. Починен счетчик шагов сессии `session-guard.ps1` (парсинг `step_index` в JSONL, эвристика пути проекта, тихий возврат 0 при неизвестной сессии).
  2. В `security-gate.ps1` внедрено исполняемое правило `PS-001` (проверка `Test-Path` с `-LiteralPath`).
  3. Усилен формат `.security-gate-allow`: привязка к правилу, файлу и номеру строки (`RULE-ID path[:line] # reason`), удалены широкие подстроки и персональные email.
  4. Устранено дублирование CLI: корневой `guardian.ps1` переведен на тонкий шим к `scripts/guardian.ps1`.
  5. Поведенческий TDD-сьют `tests/test_guardian.py` расширен с 9 до 26 автотестов (26/26 PASSED): раундтрип `checkpoint`/`rollback`, probe gate в `install-skill`, `session-guard`.
  6. В `.gitignore` добавлены `ses_*.json` и `*.transcript.json`.
- **Чекпоинт**: Релиз v2.2.0.

### [2026-11-22 12:20]
- **Что сделано**: Релиз **v2.1.0** (Harness² Recursive Scaffolding & Skill Probe Integration):
  1. Разработан скрипт `scripts/probe-skill.ps1` (валидация структуры `SKILL.md`, YAML frontmatter, UTF-8, синтаксиса `.ps1`/`.py`/`.sh` и детекция несовместимых команд Linux).
  2. Внедрен Probe Gate в `scripts/install-skill.ps1` (автоматическое зондирование скилла перед установкой в `~/.gemini/config/skills/`, блокировка с флагом `-Force`).
  3. Разработан аудит 8 измерений обвязки `scripts/audit-harness.ps1` (`guardian.ps1 harness` / `doctor.ps1 -Harness`).
  4. Добавлены команды `probe` (алиас `prb`) и `harness` (алиас `hrn`) в `guardian.ps1` CLI.
  5. TDD-тесты `tests/test_guardian.py` расширены до 9 тестов (9/9 PASSED).
- **Чекпоинт**: Релиз v2.1.0.

### [2026-11-21 21:00]
- **Что сделано**: Завершена консолидация релиза **v2.0.0** (Project Guardian CLI Facade & Global Synchronization):
  1. **Единый фасад `guardian.ps1`**: консолидировал 14 скриптов в единую точку входа с алиасами и контекстной справкой.
  2. **TDD верификация**: разработаны автотесты `tests/test_guardian.py` (5/5 PASSED).
  3. **Синхронизация глобальной установки**: глобальный каталог `~/.gemini/config/skills/project-guardian` (`C:\Users\Salomanov\.gemini\config\skills\project-guardian`) полностью синхронизирован с `origin/main` (HEAD `582da29`), протестирован через `guardian.ps1 test`, `gate` и `doctor`.
  4. **Пуш релиза**: все коммиты отправлены в удаленный репозиторий `https://github.com/salomanov/skill.git`.
- **Чекпоинт**: Релиз v2.0.0 (Consolidation Suite).

### [2026-11-22 01:40]
- **Что сделано**: Реализован релиз **v2.0.1** (Targeted Skill Recommendation Routing & Usque Archive):
  1. **Таргетированная адресация скиллов (`add-recommendation.ps1`)**: добавлен параметр `-Skill <SkillName>` (с алиасом `-SkillName`) для точной доставки рекомендаций в профильные скиллы (`~/.gemini/config/skills/<Skill>`); запрещен слепой сброс в ядро `Skill` при отсутствии параметров.
  2. **Фиксация инцидентов (`record-failure.ps1`)**: параметр `-RecommendToSkill` переведен на прием имени скилла, обновлены подсказки в консоли.
  3. **Справка фасада и тесты**: обновлена справка `guardian.ps1 recommend` в корне и `scripts/`, добавлен 6-й автотест в `tests/test_guardian.py` (6/6 PASSED).
  4. **Архивация и перенаправление**: ошибочная рекомендация по вотчдогу Usque перенаправлена в `router-ops` и заархивирована в `docs/APPLIED_RECOMMENDATIONS.md`, очищен активный `AGENT_RECOMMENDATIONS.md`.
  5. **Манифест скилла**: в Разделе 13 `SKILL.md` закреплен регламент маршрутизации рекомендаций (мета-скилл vs профильные скиллы).
- **Чекпоинт**: Релиз v2.0.1 (Targeted Skill Recommendation Routing).


## 6. Следующие Шаги
1. Использовать консолидированный фасад `guardian.ps1` во всех диалогах и проектах как единый стандарт.
2. Мониторить свежие скиллы в каталоге апстрима через `guardian.ps1 check-skills`.
