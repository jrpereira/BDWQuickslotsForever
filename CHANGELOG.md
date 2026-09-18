# Development milestones

This history combines existing Git commits with verified archived runtime
snapshots. Milestone commits preserve source with Git's configured line-ending
normalization; they do not claim that
historical tests or release records were recovered.

## 0.3.55

- Remove hook-counting instrumentation and the counter console command.
- Remove public runtime-inspection tooling and reconstruction evidence; preserve ordinary regression tests.
- Deployment preserves existing enablement and never creates an enablement marker.
- Gameplay behavior and outstanding audit findings are unchanged. Native gameplay and FPS acceptance remain separate.

## 0.3.54

- Focus the mod on ability/consumable Quickslots and wheel handling.
- Remove the unrelated input context and menu subsection.
- Keep suppression limited to the six recognized Quickslot and wheel-swap actions.
- Upgrade in a fresh game process; prior runtime mappings are not hot-migrated.
- Verified with 23 Lua suites, 13 runtime syntax checks, 20 Python tests,
  real Mod Menu metadata integration and configuration migration tests.
  Native gameplay and FPS acceptance remain unverified for this version.

## 0.3.53

- Preserve input subscriptions across routing-only changes; rebind when their
  owner or configuration changes.
- Use scoped inventory navigation, cached shortcut targets and separate wheel
  setup/formatting work.
- Keep recovery work bounded and preserve failed mapping rebuild obligations.
- Retain native key-indicator widgets and persistent action wiring.
- Current public version label omits the earlier experimental suffix.
- Offline acceptance: 23 current Lua regression suites and 14 runtime syntax
  checks. Full native integration and gameplay-performance acceptance are separate.

## 0.3.44 milestone

Archived runtime introduces dedicated persistent-input, action-indicator,
runtime-suppression, event-work and object-path modules. Later fixes are represented
by the 0.3.53 checkpoint rather than fabricated intermediate commits.

## 0.3.35 milestone

Archived runtime contains the context registry and wheel-layout modules; the
earlier input diagnostics module is no longer part of this payload.

## Existing 0.3.30 baseline

Existing Git history retains the original source, regression/release infrastructure
and user-documentation commits. Earlier and ambiguous archive variants have not
been presented as a verified linear release history.
