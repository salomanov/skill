---
name: project-guardian
description: >-
  CRITICAL MANDATORY CORE SKILL. Always active by default across ALL conversations, dialogues, and workspaces.
  Use for EVERY task, coding session, refactoring, debugging, architecture, building, or question across all
  projects (Web, Desktop, Firmware, Backend), including security audits, code reviews, and multi-project workspaces.
  Manages project memory (PROJECT_STATE.md), safety checkpoints, security gates, failure logging, rollback,
  multi-project boundaries, and autonomous skill discovery.
---
# Project Guardian (Универсальный Хранитель Проекта v2.4)

Универсальный стандарт надежности, безопасности и контекстной памяти для Google Antigravity и Gemini CLI.
Охватывает три целевые сферы:
1. 🌐 **Веб-сайты и веб-приложения** (React, Vue, Next.js, HTML/CSS/JS, FastAPI, Flask, Django).
2. 🖥️ **Программы для ПК** (PyQt6/PySide, C# .NET, Electron, Tauri, PyInstaller `.exe`).
3. 🔥 **Прошивки микроконтроллеров** (ARM Cortex, STM32, Teensy, ESP32, Arduino, PlatformIO).

---

## 1. Единый CLI-фасад (`guardian.ps1`)

Все операции Project Guardian консолидированы в единую точку входа `guardian.ps1`:

| Команда | Алиасы | Назначение |
|---|---|---|
| `checkpoint` | `cp` | Контрольная точка, бэкап, коммит (`-SubProject`, `-Verify`, `-Push`, `-Release`, `-Firmware`) |
| `doctor` | `doc` | Экспресс-диагностика рантаймов, Git, памяти и целостности проекта (`-Harness`) |
| `harness` | `hrn` | Честный аудит 8 измерений обвязки Harness² (Tools, Guardrails, Scripts, AST, BOM) |
| `probe` | `prb` | Зондирование скилла перед установкой/использованием (`-SkillPath`, `-SkillName`, `-Strict`) |
| `gate` | `sec`, `security` | Исполняемый Security Gate: секреты, антипаттерны, AST-синтаксис, BOM, REC-001 (exit 1) |
| `test` | `tests` | Авто-раннер тестов с Auto-Ensure (pytest / unittest / npm) |
| `failure` | `fail`, `record` | Моментальная фиксация сбоя в `docs/ERRORS_AND_FAILURES.md` (`-SubProject`, `-Skill`) |
| `rollback` | `rb` | Менеджер отката с просмотром снимков (`-List`, `-Step N`) |
| `handoff` | `new-chat`, `next-chat` | Авто-создание нового диалога в Antigravity и передача контекста (`.agents/HANDOFF.md`) |
| `scratch` | — | Безопасный генератор scratch-скриптов с UTF-8 и авто-считыванием кредов (`-WithSSH`) |
| `clean` | — | Безопасная ротация промежуточных бэкапов (`-Keep N`, `-DryRun`) |
| `env` | — | Сканер кодовой базы и сборка шаблона `.env.example` |
| `install` | — | Загрузчик скиллов из GitHub с Probe Gate (`-Update`, `-CheckOnly`, `-Force`) |
| `check-skills` | — | Мониторинг свежих поступлений скиллов в каталоге апстрима |
| `recommend` | — | Формирование рекомендаций для внешнего проекта или скилла (`-TargetProject`, `-Skill`) |
| `steps` | — | Проверка счетчика шагов активной сессии (`session-steps.ps1`) |
| `email` | — | Универсальный почтовый шлюз с SSL/TLS и вложениями (`send-email.ps1`) |

```powershell
.\guardian.ps1 cp -Message "feature: add oauth login"
.\guardian.ps1 gate
.\guardian.ps1 doc
.\guardian.ps1 harness
.\guardian.ps1 test
```

---

## 2. Чек-лист Жизненного Цикла Сессии (Session Lifecycle Checklist)

1. **Старт диалога**: Считать `PROJECT_STATE.md` в корне активного проекта/подпроекта. Если файла нет — создать по эталону `references/PROJECT_STATE_TEMPLATE.md`.
2. **Перед любым изменением кода**: Создать защитную контрольную точку:
   `.\guardian.ps1 cp -Message "<описание задачи>"`
3. **При любом сбое, зависании, ошибке компиляции или аппаратных граблях**: Немедленно зафиксировать инцидент ДО повторных попыток:
   `.\guardian.ps1 fail -Title "<кратко>" -Symptom "<что сломалось>" -RootCause "<причина>" -Solution "<как решено>"`
4. **Перед сдачей задачи**: Запустить проверку гейта безопасности и тестов:
   `.\guardian.ps1 gate`
   `.\guardian.ps1 test`
5. **При завершении этапа**: Актуализировать `PROJECT_STATE.md` (статус, история изменений).
6. **Контекстная гигиена и новый диалог**: При приближении к порогу перегрузки или по запросу пользователя («пошли в новый диалог», «создай новый чат») агент запускает `.\guardian.ps1 handoff`, автоматически создает новый диалог через Antigravity ConversationService и сразу предоставляет ссылку: `[Открыть новый диалог: <Название>](conversation://<id>)`. Ручное копирование больше не требуется.

---

## 3. Долговременная память (`PROJECT_STATE.md`)

- Файл хранит Product Goals, текущий статус, структуру, стек, список регрессий (`4a. Regressions`) и историю последних 5–7 релизов.
- Архив ранних версий выносится в `docs/HISTORICAL_STATES.md` для сохранения компактности контекста.
- В составных воркспейсах (монорепозиториях) память ведется изолированно в каждом подпроекте.

---

## 4. Контрольные точки и несгораемые архивы (`checkpoint.ps1`)

- **Запрет слепого пуша**: `checkpoint.ps1` коммитит локально. Пуш в remote выполняется **строго по явному флагу `-Push`**.
- **Несгораемые релизные архивы**: сборки `.exe`, веб-бандлы `dist/` и удачные прошивки микроконтроллеров сохраняются в `.backups/` в уникальные папки с таймштампом (`desktop_release_*`, `web_release_*`, `firmware_success_*`), паспортом SHA256 (`RELEASE_INFO.md`) и тегом Git. Предыдущие релизы никогда не перезаписываются.
- **Изоляция в составных воркспейсах**: всегда передавать `-SubProject <имя>` или `-ProjectPath <путь>`, чтобы не раздувать родительскую папку гигабайтными снимками.

---

## 5. Исполняемый Security & Reliability Gate (`security-gate.ps1`)

Исполняемый барьер, завершающийся с кодом `1` при обнаружении нарушений:
- `SEC-001..005`: Утечки учетных данных, паролей, токенов и секретных ключей.
- `SEC-010..017`: Антипаттерны (`curl | sh`, `shell=True`, `verify=False`, `auth.enabled=false`, `chmod 777`, wildcard CORS).
- `PS-001`: Вызовы `Test-Path` без `-LiteralPath` (защита от `WildcardPatternException` на путях с квадратными скобками).
- `SYNTAX-BOM`: Проверка отсутствия UTF-8 BOM в Linux shell-скриптах (`.sh`) и файлах Android (`.kl`, `.idc`).
- `REC-001`: Требование архивации закрытых задач `[x] ВЫПОЛНЕНО` из `AGENT_RECOMMENDATIONS.md` в `docs/APPLIED_RECOMMENDATIONS.md`.
- **Строгий allowlist**: исключения оформляются строго в формате `RULE-ID path[:line] # reason` в файле `.security-gate-allow`. Широкие подстрочные исключения запрещены.

---

## 6. Дисциплина командной строки Windows (Zero Exit Code 1)

1. **Запрет сложных однострочников**: категорически запрещены инлайн-вызовы `python -c "..."` или `powershell -Command "..."` с вложенными кавычками, пайпами, спецсимволами `$` и `&`.
2. **Шаблон из 2 шагов**: скрипты всегда создаются как файл через `guardian.ps1 scratch` или `write_file` в папку `scratch/<task>.py` / `.sh`, после чего запускаются файлом.
3. **Гарантия UTF-8**: все Python скрипты обязаны содержать `import sys; sys.stdout.reconfigure(encoding='utf-8')`. Скрипты PowerShell обязаны сохраняться с UTF-8 BOM.
4. **Read Credentials & Config First**: запрещено угадывать порты, логины и пароли по умолчанию. Параметры предварительно считываются из конфигураций и `deploy.py`.
5. **Пути с квадратными скобками**: в PowerShell (`Test-Path`, `Get-Item`, `Get-ChildItem`) всегда использовать `-LiteralPath`.

---

## 7. Межпроектная изоляция и протокол рекомендаций (`AGENT_RECOMMENDATIONS.md`)

- **Граница воркспейса**: агенту категорически запрещено модифицировать код проектов за пределами текущей рабочей папки (`(Get-Location).Path`). Внешние проекты строго Read-Only.
- **Режим рекомендаций**: если замечена необходимая правка во внешнем проекте или профильном скилле:
  1. Вызвать: `.\guardian.ps1 recommend -TargetProject <path>` или `.\guardian.ps1 recommend -Skill <skill-name>` с описанием и diff-сниппетом.
  2. Запрещено сбрасывать рекомендации в ядро Guardian (`Skill`) при наличии целевого доменного проекта.
  3. Закрытые рекомендации `[x] ВЫПОЛНЕНО` архивируются в `docs/APPLIED_RECOMMENDATIONS.md`.

---

## 8. Definition of Done

Задача считается сданной только при соблюдении 7 условий:
1. Код решает задачу минимальным достаточным объемом (принцип Ponytail).
2. Выполнен запуск тестов: `.\guardian.ps1 test` завершился с exit code `0`.
3. Пройден гейт безопасности: `.\guardian.ps1 gate` завершился с exit code `0`.
4. Актуализирован `PROJECT_STATE.md` (статус, регрессии, история).
5. Создана контрольная точка `.\guardian.ps1 cp -Message "..."`.
6. Рабочее дерево Git чистое, нет случайных мусорных файлов в корне.
7. Пользователю предоставлен краткий и емкий консольный отчет со ссылками на измененные файлы.

---

## 9. Подключаемые Справочные Модули (`references/`)

Узкоспециализированные инструкции вынесены в отдельные справочники и читаются по требованию:
- 🧪 **Selective TDD**: [references/SELECTIVE_TDD.md](references/SELECTIVE_TDD.md) — обязательный 3-фазный цикл RED $
ightarrow$ GREEN $
ightarrow$ REFACTOR для критичной бизнес-логики и список явных исключений.
- 🏢 **Составные воркспейсы**: [references/MULTI_PROJECT_GUIDE.md](references/MULTI_PROJECT_GUIDE.md) — регламент монорепозиториев, защита от раздувания бэкапов и параметры `-SubProject`.
- 🛡️ **Harness² Probe & Audit**: [references/HARNESS2_PROBE.md](references/HARNESS2_PROBE.md) — архитектура зондирования скиллов (Propose-Probe-Compose) и аудит 8 измерений обвязки агента.
- ✉️ **Почтовый шлюз**: [references/SEND_EMAIL.md](references/SEND_EMAIL.md) — отправка писем и отчетов с вложениями через SMTP (`send-email.ps1`).
- 📋 **Шаблон памяти**: [references/PROJECT_STATE_TEMPLATE.md](references/PROJECT_STATE_TEMPLATE.md) — эталонный шаблон `PROJECT_STATE.md`.
