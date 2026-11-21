# Graph Report - Skill  (2026-11-22)

## Corpus Check
- 19 files · ~29,229 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 3 file(s) not represented in the graph (top: (none) 3)

## Summary
- 65 nodes · 80 edges · 19 communities (3 shown, 16 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `33d9e26a`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- get_dialog_title.py
- send-email.py
- test_guardian.py

## God Nodes (most connected - your core abstractions)
1. `run_guardian()` - 9 edges
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
- `match_workspace()` --calls--> `json`  [EXTRACTED]
  scripts/get_dialog_title.py →   _Bridges community 0 → community 1_

## Import Cycles
- None detected.

## Communities (19 total, 16 thin omitted)

### Community 0 - "get_dialog_title.py"
Cohesion: 0.42
Nodes (7): clean_title(), get_dialog_title(), is_generic_title(), main(), match_workspace(), normalize_uri_path(), set_dialog_title()

### Community 1 - "send-email.py"
Cohesion: 0.17
Nodes (3): load_config(), main(), send_email()

### Community 18 - "test_guardian.py"
Cohesion: 0.31
Nodes (7): run_guardian(), test_guardian_gate(), test_guardian_no_args(), test_guardian_recommend_no_target_fails(), test_guardian_root_help(), test_guardian_scripts_help(), test_guardian_unknown_command()

## Knowledge Gaps
- **16 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `match_workspace()` connect `get_dialog_title.py` to `send-email.py`?**
  _High betweenness centrality (0.005) - this node is a cross-community bridge._
- **Why does `main()` connect `send-email.py` to `get_dialog_title.py`?**
  _High betweenness centrality (0.005) - this node is a cross-community bridge._