# Graph Report - Skill  (2026-11-22)

## Corpus Check
- 21 files · ~31,847 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 3 file(s) not represented in the graph (top: (none) 3)

## Summary
- 71 nodes · 87 edges · 21 communities (3 shown, 18 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `908ca640`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- get_dialog_title.py
- send-email.py
- test_guardian.py

## God Nodes (most connected - your core abstractions)
1. `run_guardian()` - 12 edges
2. `get_dialog_title()` - 6 edges
3. `set_dialog_title()` - 6 edges
4. `main()` - 5 edges
5. `match_workspace()` - 5 edges
6. `send_email()` - 5 edges
7. `clean_title()` - 4 edges
8. `main()` - 4 edges
9. `is_generic_title()` - 3 edges
10. `load_config()` - 3 edges

## Surprising Connections (you probably didn't know these)
- `main()` --calls--> `argparse`  [EXTRACTED]
  scripts/get_dialog_title.py →   _Bridges community 0 → community 1_

## Import Cycles
- None detected.

## Communities (21 total, 18 thin omitted)

### Community 0 - "get_dialog_title.py"
Cohesion: 0.42
Nodes (7): clean_title(), get_dialog_title(), is_generic_title(), main(), match_workspace(), normalize_uri_path(), set_dialog_title()

### Community 1 - "send-email.py"
Cohesion: 0.17
Nodes (3): load_config(), main(), send_email()

### Community 18 - "test_guardian.py"
Cohesion: 0.25
Nodes (10): run_guardian(), test_guardian_gate(), test_guardian_harness_audit(), test_guardian_no_args(), test_guardian_probe_invalid_dir(), test_guardian_probe_self(), test_guardian_recommend_no_target_fails(), test_guardian_root_help() (+2 more)

## Knowledge Gaps
- **18 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Not enough signal to generate questions. This usually means the corpus has no AMBIGUOUS edges, no bridge nodes, no INFERRED relationships, and all communities are tightly cohesive. Add more files or run with --mode deep to extract richer edges._