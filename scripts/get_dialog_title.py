#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import argparse
import json
import sqlite3
import sys
import urllib.parse
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

DB_PATH = Path.home() / ".gemini" / "antigravity" / "conversation_summaries.db"

GENERIC_PREFIXES = (
    "привет! мы продолжаем",
    "тема диалога:",
    "название диалога:",
    "continuing work on",
)

def normalize_uri_path(uri: str) -> str:
    if not uri:
        return ""
    clean = uri[8:] if uri.startswith("file:///") else (uri[7:] if uri.startswith("file://") else uri)
    clean = urllib.parse.unquote(clean).replace("/", "\\").rstrip("\\")
    return clean.lower()

def is_generic_title(title: str) -> bool:
    if not title or not title.strip():
        return True
    t = title.strip().lower()
    return any(t.startswith(p) for p in GENERIC_PREFIXES)

def clean_title(title: str) -> str:
    if not title:
        return ""
    t = title.strip()
    for prefix in ("Тема диалога:", "Название диалога:", "тема диалога:", "название диалога:"):
        if t.startswith(prefix):
            t = t[len(prefix):].strip()
    return t

def match_workspace(w_json: str, target_path: str) -> bool:
    if not w_json or not target_path:
        return False
    norm_target = target_path.replace("/", "\\").rstrip("\\").lower()
    try:
        uris = json.loads(w_json)
        for u in uris:
            np = normalize_uri_path(u)
            if np == norm_target or norm_target.startswith(np + "\\") or np.startswith(norm_target + "\\"):
                return True
    except Exception:
        pass
    return False

def get_dialog_title(cid: str, project_path: str) -> str:
    if not DB_PATH.exists():
        return ""
    try:
        conn = sqlite3.connect(f"file:{DB_PATH}?mode=ro", uri=True, timeout=5)
        cur = conn.cursor()
        if cid:
            row = cur.execute(
                "SELECT title FROM conversation_summaries WHERE conversation_id = ?",
                (cid.strip(),)
            ).fetchone()
            if row and row[0] and not is_generic_title(row[0]):
                conn.close()
                return clean_title(row[0])

        rows = cur.execute(
            "SELECT conversation_id, title, workspace_uris FROM conversation_summaries ORDER BY last_modified_time DESC LIMIT 50"
        ).fetchall()
        conn.close()

        for r_cid, r_title, r_uris in rows:
            if match_workspace(r_uris, project_path):
                if r_title and not is_generic_title(r_title):
                    return clean_title(r_title)
    except Exception:
        pass
    return ""

def set_dialog_title(cid: str, project_path: str, new_title: str) -> bool:
    if not DB_PATH.exists() or not new_title:
        return False
    cleaned = clean_title(new_title)
    if not cleaned:
        return False
    try:
        conn = sqlite3.connect(str(DB_PATH), timeout=5)
        cur = conn.cursor()
        target_cid = (cid or "").strip()
        if not target_cid and project_path:
            rows = cur.execute(
                "SELECT conversation_id, title, workspace_uris FROM conversation_summaries ORDER BY last_modified_time DESC LIMIT 20"
            ).fetchall()
            for r_cid, r_title, r_uris in rows:
                if match_workspace(r_uris, project_path):
                    target_cid = r_cid
                    break
        if target_cid:
            row = cur.execute(
                "SELECT title FROM conversation_summaries WHERE conversation_id = ?",
                (target_cid,)
            ).fetchone()
            if row and (is_generic_title(row[0]) or row[0].strip().lower().startswith("тема диалога:")):
                cur.execute(
                    "UPDATE conversation_summaries SET title = ? WHERE conversation_id = ?",
                    (cleaned, target_cid)
                )
                conn.commit()
                conn.close()
                return True
        conn.close()
    except Exception:
        pass
    return False

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["get", "set"], default="get")
    parser.add_argument("--cid", default="")
    parser.add_argument("--path", default="")
    parser.add_argument("--title", default="")
    args = parser.parse_args()

    if args.mode == "get":
        res = get_dialog_title(args.cid, args.path)
        if res:
            print(res)
    elif args.mode == "set":
        if set_dialog_title(args.cid, args.path, args.title):
            print(clean_title(args.title))

if __name__ == "__main__":
    main()
