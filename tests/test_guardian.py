import subprocess
import sys
from pathlib import Path
import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent

def run_guardian(script_path: Path, *args):
    cmd = ["powershell", "-NoProfile", "-File", str(script_path)] + list(args)
    proc = subprocess.run(
        cmd,
        cwd=str(REPO_ROOT),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace"
    )
    return proc

def test_guardian_root_help():
    p = REPO_ROOT / "guardian.ps1"
    assert p.exists()
    res = run_guardian(p, "--help")
    assert res.returncode == 0
    assert "Project Guardian v2.0 CLI" in res.stdout
    assert "checkpoint" in res.stdout
    assert "doctor" in res.stdout

def test_guardian_scripts_help():
    p = REPO_ROOT / "scripts" / "guardian.ps1"
    assert p.exists()
    res = run_guardian(p, "-h")
    assert res.returncode == 0
    assert "Project Guardian v2.0 CLI" in res.stdout

def test_guardian_no_args():
    p = REPO_ROOT / "guardian.ps1"
    res = run_guardian(p)
    assert res.returncode == 0
    assert "Использование: guardian.ps1" in res.stdout

def test_guardian_unknown_command():
    p = REPO_ROOT / "guardian.ps1"
    res = run_guardian(p, "unknown_command_404")
    assert res.returncode == 1
    assert "Неизвестная команда Guardian" in res.stdout

def test_guardian_gate():
    p = REPO_ROOT / "guardian.ps1"
    res = run_guardian(p, "gate")
    assert res.returncode == 0
    assert "SECURITY GATE PASSED" in res.stdout
