# Graph Report - Skill  (2026-11-21)

## Corpus Check
- 16 files · ~25,874 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 3 file(s) not represented in the graph (top: (none) 3)

## Summary
- 48 nodes · 57 edges · 18 communities (1 shown, 17 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `6aa11894`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- get_dialog_title.py
- argparse
- send_email

## God Nodes (most connected - your core abstractions)
1. `get_dialog_title()` - 6 edges
2. `set_dialog_title()` - 6 edges
3. `main()` - 5 edges
4. `match_workspace()` - 5 edges
5. `send_email()` - 5 edges
6. `clean_title()` - 4 edges
7. `main()` - 4 edges
8. `is_generic_title()` - 3 edges
9. `load_config()` - 3 edges
10. `normalize_uri_path()` - 2 edges

## Surprising Connections (you probably didn't know these)
- `main()` --calls--> `argparse`  [EXTRACTED]
  scripts/get_dialog_title.py →   _Bridges community 0 → community 3_
- `match_workspace()` --calls--> `json`  [EXTRACTED]
  scripts/get_dialog_title.py →   _Bridges community 0 → community 4_
- `main()` --calls--> `send_email()`  [EXTRACTED]
  scripts/send-email.py → scripts/send-email.py  _Bridges community 3 → community 4_

## Import Cycles
- None detected.

## Communities (18 total, 17 thin omitted)

### Community 0 - "get_dialog_title.py"
Cohesion: 0.47
Nodes (7): clean_title(), get_dialog_title(), is_generic_title(), main(), match_workspace(), normalize_uri_path(), set_dialog_title()

## Knowledge Gaps
- **17 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `match_workspace()` connect `get_dialog_title.py` to `send_email`?**
  _High betweenness centrality (0.009) - this node is a cross-community bridge._
- **Why does `main()` connect `get_dialog_title.py` to `argparse`?**
  _High betweenness centrality (0.008) - this node is a cross-community bridge._
- **Why does `main()` connect `argparse` to `send-email.py`, `send_email`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._