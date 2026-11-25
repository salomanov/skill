# Graph Report - Skill  (2026-11-25)

## Corpus Check
- 23 files · ~31,513 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 3 file(s) not represented in the graph (top: (none) 3)

## Summary
- 117 nodes · 180 edges · 31 communities (5 shown, 26 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 2 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `559dc7c5`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- get_dialog_title.py
- send-email.py
- security-gate.ps1
- test_harness_detects_version_drift
- make_project
- test_repo_allowlist_uses_strict_format
- test_guardian.py
- session-guard.ps1
- test_install_skill_calls_probe_gate
- make_transcript
- test_checkpoint_and_rollback_roundtrip
- test_step_counter_silent_when_session_unknown
- test_harness_reports_blockers
- test_harness_detects_broken_guardian_tool
- test_harness_detects_broken_script_syntax
- test_root_facade_is_thin_shim

## God Nodes (most connected - your core abstractions)
1. `run_ps()` - 31 edges
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
- `test_checkpoint_and_rollback_roundtrip()` --calls--> `run_ps()`  [EXTRACTED]
  tests/test_guardian.py → tests/test_guardian.py  _Bridges community 18 → community 26_
- `test_harness_detects_broken_guardian_tool()` --calls--> `run_ps()`  [EXTRACTED]
  tests/test_guardian.py → tests/test_guardian.py  _Bridges community 18 → community 29_
- `test_harness_detects_broken_script_syntax()` --calls--> `run_ps()`  [EXTRACTED]
  tests/test_guardian.py → tests/test_guardian.py  _Bridges community 18 → community 30_
- `test_harness_detects_version_drift()` --calls--> `run_ps()`  [EXTRACTED]
  tests/test_guardian.py → tests/test_guardian.py  _Bridges community 18 → community 3_

## Import Cycles
- None detected.

## Communities (31 total, 26 thin omitted)

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
Cohesion: 0.26
Nodes (11): run_ps(), test_gate_detects_curl_pipe_sh(), test_gate_passes_on_this_repo(), test_guardian_harness_audit(), test_guardian_no_args(), test_guardian_probe_invalid_dir(), test_guardian_probe_self(), test_guardian_recommend_no_target_fails() (+3 more)

### Community 25 - "make_transcript"
Cohesion: 0.50
Nodes (4): make_transcript(), test_step_counter_counts_steps_not_lines(), test_step_counter_threshold_exit_code(), test_steps_via_facade()

## Knowledge Gaps
- **26 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `run_ps()` connect `test_guardian.py` to `test_harness_detects_version_drift`, `make_project`, `make_transcript`, `test_checkpoint_and_rollback_roundtrip`, `test_step_counter_silent_when_session_unknown`, `test_harness_reports_blockers`, `test_harness_detects_broken_guardian_tool`, `test_harness_detects_broken_script_syntax`, `test_root_facade_is_thin_shim`?**
  _High betweenness centrality (0.067) - this node is a cross-community bridge._
- **Why does `secret_line()` connect `make_project` to `test_guardian.py`?**
  _High betweenness centrality (0.012) - this node is a cross-community bridge._
- **Why does `test_gate_allowlist_strict_entry_is_narrow()` connect `make_project` to `test_guardian.py`?**
  _High betweenness centrality (0.012) - this node is a cross-community bridge._