# Harness² Recursive Scaffolding & 8 Dimensions Audit

## 21. Интеграция с принципами Harness² (Google Research): Зондирование и 8 Измерений Обвязки

### 21.1. Концепция Recursive Agent Harnessing в Project Guardian
В соответствии с исследованиями *Harness²* (Google Research & Northwestern Univ., arXiv:2610.14224), надежность автономного агента определяется качеством его **обвязки (Harness)** вокруг неизменяемых весов модели. Project Guardian структурирует обвязку по 8 независимым измерениям:
1. **System Prompts**: Глобальные инварианты `AGENTS.md` (Ponytail, Zero Exit Code 1, Project Guardian).
2. **Tools**: Консолидированный фасад `guardian.ps1` (16 команд).
3. **Memory**: Долговременная память `PROJECT_STATE.md` + граф знаний `graphify`.
4. **Guardrails**: Исполняемый барьер `security-gate.ps1` (AST-анализ и поиск секретов).
5. **Scripts**: Авто-генераторы `new-scratch.ps1`, `send-email.ps1`, `doctor.ps1`.
6. **Skills**: Каталог `~/.gemini/config/skills/`, загрузчик `install-skill.ps1` и мониторинг `check-new-skills.ps1`.
7. **Subagents**: Межпроектная изоляция и передача контекста `prepare-handoff.ps1`.
8. **Control Hooks**: Реактивное пробуждение (`Reactive Wakeup`), стоппер сессий (150–200 шагов).

### 21.2. Аудит обвязки (`guardian.ps1 harness`)
Для моментальной проверки здоровья всех 8 измерений в текущем проекте используется команда:
```powershell
./guardian.ps1 harness
# или через алиас
./guardian.ps1 hrn
```

### 21.3. Цикл Propose-Probe-Compose: Зондирование скиллов (`guardian.ps1 probe`)
Перед допуском любого стороннего скилла в рабочую среду выполняется зондирование (`Probe`) скриптом `scripts/probe-skill.ps1`:
```powershell
# Зондирование локального скилла по пути
./guardian.ps1 probe -SkillPath .\skills\custom-tool

# Зондирование установленного скилла по имени
./guardian.ps1 probe -SkillName router-ops
```
**Критерии зондирования**:
1. Наличие валидного манифеста `SKILL.md` и YAML frontmatter (`name`, `description`).
2. Отсутствие несовместимых команд Linux (`sudo`, `apt-get`, `yum`, `brew`) без альтернатив для Windows.
3. Валидный синтаксис всех встроенных скриптов: PowerShell (AST-парсер), Python (`py_compile`), Shell (проверка отсутствия UTF-8 BOM).
4. Безопасность: отсутствие открытых приватных ключей и паролей.

В скрипте `install-skill.ps1` зондирование выполняется автоматически перед регистрацией скилла. При непрохождении зонда установка блокируется (обход только через явный флаг `-Force`).






