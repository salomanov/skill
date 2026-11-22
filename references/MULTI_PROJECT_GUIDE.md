# Multi-Project Workspaces & Mono-Repositories Invariants

## 14. Работа в составных воркспейсах и монорепозиториях (Multi-Project Workspaces)

Частая ситуация: в одной общей папке (например, `Router_Workspace`) находятся несколько отдельных подпроектов (`Router_api`, `Opds`, `Tuya`, `MQTT`), для каждого из которых ведется собственный диалог и собственный `PROJECT_STATE.md`.

### 🚨 Главная ловушка: Раздувание бэкапов и засорение родительской папки
Если агент запускает `checkpoint.ps1` или `record-failure.ps1` без параметров, по умолчанию скрипты берут текущий рабочий каталог воркспейса `(Get-Location).Path`. В результате:
1. `checkpoint.ps1` копирует в `.backups/` **весь воркспейс целиком вместе со всеми соседними подпроектами**, создавая гигабайтные дубликаты!
2. `record-failure.ps1` создает базу ошибок `docs/ERRORS_AND_FAILURES.md` в корне общего воркспейса вместо папки целевого подпроекта!

### 🛡️ Железные правила для составных воркспейсов:
1. **Определение активного подпроекта на старте**:
   При входе в диалог агент проверяет: если текущий каталог содержит вложенные папки с собственными `PROJECT_STATE.md`, агент обязан идентифицировать, в каком именно подпроекте идет работа (по теме запроса пользователя или по `git status`).
2. **Всегда передавать `-ProjectPath` или `-SubProject`**:
   Все скрипты Guardian обязаны вызываться с указанием пути к конкретному подпроекту:
   ```powershell
   # Создание чекпоинта подпроекта:
   & "C:\Users\Salomanov\.gemini\config\skills\project-guardian\scripts\checkpoint.ps1" -ProjectPath "E:\Projects\Router_Workspace\Opds" -Message "Обновление OPDS"
   # Или коротко через флаг -SubProject:
   & "C:\Users\Salomanov\.gemini\config\skills\project-guardian\scripts\checkpoint.ps1" -SubProject "Opds" -Message "Обновление OPDS"

   # Фиксация сбоев изолированно в подпроект:
   & "C:\Users\Salomanov\.gemini\config\skills\project-guardian\scripts\record-failure.ps1" -SubProject "Opds" -Title "Сбой" -Symptom "..."

   # Security Gate только для подпроекта:
   & "C:\Users\Salomanov\.gemini\config\skills\project-guardian\scripts\security-gate.ps1" -ProjectPath "E:\Projects\Router_Workspace\Opds"

   # Откат только для подпроекта:
   & "C:\Users\Salomanov\.gemini\config\skills\project-guardian\scripts\rollback.ps1" -ProjectPath "E:\Projects\Router_Workspace\Opds"
   ```
3. **Автоопределение в скриптах**:
   - `checkpoint.ps1` автоматически определяет активный подпроект по изменениям в Git и направляет архив в `<подпроект>/.backups/`.
   - `record-failure.ps1` автоматически определяет активный подпроект по упоминаемым именам файлов (`.py`, `.js`, `.sh` и др.) и тексту сбоя, сохраняя инцидент в `<подпроект>/docs/ERRORS_AND_FAILURES.md`.
4. **Защита корня от дублирования**:
   При осознанном создании чекпоинта родительской папки вложенные подпроекты (имеющие собственный `PROJECT_STATE.md`) **автоматически исключаются из бэкапа**, если явно не передан флаг `-IncludeSubprojects`.

---

