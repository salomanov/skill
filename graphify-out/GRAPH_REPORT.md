# Graph Report - Skill  (2026-11-22)

## Corpus Check
- 23 files · ~33,386 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 3 file(s) not represented in the graph (top: (none) 3)

## Summary
- 110 nodes · 167 edges · 25 communities (4 shown, 21 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `30b3b936`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- get_dialog_title.py
- send-email.py
- make_project
- test_repo_allowlist_uses_strict_format
- test_guardian.py
- session-guard.ps1
- test_install_skill_calls_probe_gate

## God Nodes (most connected - your core abstractions)
1. `run_ps()` - 28 edges
2. `make_project()` - 10 edges
3. `secret_line()` - 6 edges
4. `make_transcript()` - 6 edges
5. `get_dialog_title()` - 6 edges
6. `set_dialog_title()` - 6 edges
7. `test_gate_detects_test_path_without_literalpath()` - 5 edges
8. `test_gate_allowlist_strict_entry_is_narrow()` - 5 edges
9. `test_gate_allowlist_legacy_entry_warns()` - 5 edges
10. `main()` - 5 edges

## Surprising Connections (you probably didn't know these)
- `run_ps()` --references--> `Path`  [EXTRACTED]
  tests/test_guardian.py →   _Bridges community 18 → community 6_
- `make_transcript()` --calls--> `json`  [EXTRACTED]
  tests/test_guardian.py →   _Bridges community 18 → community 0_
- `load_config()` --calls--> `json`  [EXTRACTED]
  scripts/send-email.py →   _Bridges community 1 → community 0_

## Import Cycles
- None detected.

## Communities (25 total, 21 thin omitted)

### Community 0 - "get_dialog_title.py"
Cohesion: 0.38
Nodes (7): clean_title(), get_dialog_title(), is_generic_title(), main(), match_workspace(), normalize_uri_path(), set_dialog_title()

### Community 1 - "send-email.py"
Cohesion: 0.18
Nodes (3): load_config(), main(), send_email()

### Community 6 - "make_project"
Cohesion: 0.17
Nodes (10): make_project(), secret_line(), test_gate_accepts_test_path_with_literalpath(), test_gate_allowlist_legacy_entry_warns(), test_gate_allowlist_strict_entry_excuses_target_line(), test_gate_allowlist_strict_entry_is_narrow(), test_gate_detects_planted_secret(), test_gate_detects_ps1_without_bom() (+2 more)

### Community 18 - "test_guardian.py"
Cohesion: 0.14
Nodes (19): make_transcript(), run_ps(), test_checkpoint_and_rollback_roundtrip(), test_gate_detects_curl_pipe_sh(), test_gate_passes_on_this_repo(), test_guardian_harness_audit(), test_guardian_no_args(), test_guardian_probe_invalid_dir() (+11 more)

## Knowledge Gaps
- **21 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `run_ps()` connect `test_guardian.py` to `make_project`?**
  _High betweenness centrality (0.057) - this node is a cross-community bridge._
- **Should `test_guardian.py` be split into smaller, more focused modules?**
  _Cohesion score 0.14461538461538462 - nodes in this community are weakly interconnected._
- **Why does `secret_line()` connect `make_project` to `test_guardian.py`?**
  _High betweenness centrality (0.013) - this node is a cross-community bridge._
- **Why does `test_gate_allowlist_strict_entry_is_narrow()` connect `make_project` to `test_guardian.py`?**
  _High betweenness centrality (0.013) - this node is a cross-community bridge._