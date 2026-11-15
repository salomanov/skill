# Changelog

All notable changes to Project Guardian are documented in this file.

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
