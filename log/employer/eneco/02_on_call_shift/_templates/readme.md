# On-call intake templates

Reusable templates for agent-ready incident intakes under `02_on_call_shift/`.

## Files

| File | Purpose |
|------|---------|
| [slack-intake.template.md](./slack-intake.template.md) | Canonical structure for agent **`intake.md`** in an incident folder |

## Harness skill

Render **`intake.md`** only with [`eneco-oncall-troubleshooting-spec`](../../../../.ai/harness/skills/eneco-oncall-troubleshooting-spec.md). Bundled template + Stefan example: `.ai/harness/skills/eneco-oncall-troubleshooting-spec/`.

## Derive a new incident intake

1. Use `eneco-oncall-troubleshooting-spec` or render from [slack-intake.template.md](./slack-intake.template.md) — do **not** copy the template file into the incident folder.
2. Write `log/employer/eneco/02_on_call_shift/{period}/{incident_dir}/intake.md`.
3. Set the [derivation header](./slack-intake.template.md#derivation-header) (template path, version, instance id, filled date).
4. Fill [Instance manifest](./slack-intake.template.md#instance-manifest) from intake evidence.
5. Render generic sections from the template (substitute `{{PLACEHOLDER}}` values).
6. Keep raw Slack paste in `slack-intake.txt` per [on-call-log-entry](../../../../../.ai/harness/skills/on-call-log-entry.md) skill.

## Maintain the template

When improving intake structure (UAC, context fetch, skills):

1. Edit `slack-intake.template.md` only.
2. Bump `template_version` in the template derivation header comment.
3. Re-render open incident `slack-intake.md` files when they should pick up generic changes.

## First derived instance

- [2026_02_22_001_fbe_404_stefan](../2026_june/2026_02_22_001_fbe_404_stefan/slack-intake.md) — FBE 404 / operations slot (2026-06-22)
