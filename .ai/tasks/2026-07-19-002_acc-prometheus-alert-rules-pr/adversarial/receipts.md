---
title: Adversarial receipts — DispatcherOutputHealthZero PromQL review
type: review
status: complete
task_id: 2026-07-19-002
agent: claude-opus-4-8
summary: Disposition of every finding from russell (logic), sre-maniac (ops), librarian (docs) against Alex's proposed absent-aware PromQL; three frames converge on the same core hazards.
timestamp: 2026-07-19
---

# Adversarial receipts

Three independent typed frames attacked Alex's proposed fix
`avg_over_time(dispatcher_output_health{exported_job="Activation mFRR"}[2m]) == 0 or absent_over_time(...[2m]) == 1`.
Convergence: russell (logic) and sre-maniac (ops) reached the **same** two core hazards
from different directions; librarian confirmed every doc-semantic both relied on.

| # | Finding (source) | Disposition | Evidence / action |
|---|------------------|-------------|-------------------|
| 1 | **Absent arm false-fires 24/7** because `dispatcher_output_health` matches 0 series today (sre FM1 + russell assumption-3) | **RESOLVE** | Merge precondition: absent arm ships only after `count(dispatcher_output_health{exported_job="Activation mFRR"}) > 0` in a healthy env. In `fix.md`. |
| 2 | **`or`-arm label mismatch resets `for:`** on present-0↔absent flap (sre FM2 + russell §label-set) | **RESOLVE** | Unify labels: `max by (exported_job)(...)` + `absent(...)` both emit `{exported_job="Activation mFRR"}`; or split into two alertnames. |
| 3 | **Double dwell ~4m** (`avg_over_time[2m]` + `for:2m`) (sre FM3) | **RESOLVE** | Use instant gauge + single `for:` (drop the `_over_time` window on the health arm). |
| 4 | **Float-brittle `== 0`** (sre FM4) + non-negativity assumption (russell) | **RESOLVE** | Use `< 1` (russell: `max_over_time < 1` encodes "never healthy") or `<= 0`; robust to intermediate/negative values. |
| 5 | **Partial-replica absence silent** if selector matches >1 series (sre FM5 + russell Case 5) | **DEFER** | Revisit when the metric emits: run `count(...)`; if >1 add `count(...) < <expected>` warning. Cardinality unknown until metric flows. |
| 6 | **Selector-truth**: `absent()` cannot tell "went away" from "never existed / wrong `exported_job`" (russell Theory-of-Descriptions) | **RESOLVE** | Same precondition as #1 + confirm exact `__name__`/`exported_job` when the metric first emits (note: `exported_job` is a relabel-collision prefix). |
| 7 | **`== 1` on absent arm is redundant** (russell) | **REBUT (partial)** | The shared template `prometheus-rule.yaml` ALWAYS appends `<exprOperator> <thresholdValue>` (`printf "%s %s %s"`), so a bare `absent(...)` is not renderable — `== 1` is **forced by the template**, not cosmetic. Keep it. |
| 8 | Alex's "`avg_over_time` returns NaN on empty window" is **FALSE** (librarian) | **RESOLVE (teach)** | Correct mechanism: empty window → series is *dropped* (no output), not NaN. Alex's conclusion (`==0` doesn't fire on absence) still holds. Documented in the Feynman explainer. |
| 9 | Uppercase `OR` is a parse error but **undocumented** (librarian) | **DEFER (verify)** | Practitioner fact, no citable doc sentence. Committed YAML must use lowercase `or`. Verify with `promtool check rules` before merge. |

## Net verdict

Alex's proposal is **logically correct but operationally fragile**; the committed
code (`avg_over_time(...) == 0`) is **worse** (silent on total absence). The
**most-solid verified approach** is the unified-label / two-alert form in
`context/synthesis-recommendation.md`, gated on the metric-emission precondition.
No finding was Rebutted without evidence; DEFERs carry an explicit revisit condition.
