# Development milestones

This history combines existing Git commits with verified archived runtime
snapshots. Milestone commits preserve source with Git's configured line-ending
normalization; they do not claim that
historical tests or release records were recovered.

## 0.3.61

- Remove unused context-name scanning, sorting and concatenation during input recovery. Preserve gameplay context repair and the initialization routing log.

## 0.3.60

- Finish partial suppression/restoration writes on a direct Restore retry, including after Lua reload, without discarding original settings behavior.
- Reserve known native keys one-to-one before matching suppressed duplicate rows; preserve explicit failure for genuinely ambiguous identity.
- Mark only rows actually being restored as in-progress, preserving unrelated external changes after a failed restoration.
- Prune dead completed wheel-setup records during new setup work, without polling or extra work for unchanged completed requests.
- Regression coverage includes direct retries, duplicate known-key insertion, external behavior changes and 1000 HUD replacements. Native gameplay/FPS acceptance remains pending.

## 0.3.59

- Validate requested keys before replacing active shortcuts; add standard missing keyboard keys including Caps Lock, Backspace, Enter and modifiers.
- Restore native mappings before the game applies Controls changes. Ambiguous external edits to already-suppressed duplicate mappings retain their journal and report that a native Controls reset is required, rather than guessing keys.
- Preserve original fields through interrupted suppression/restoration writes and Lua reloads.
- Cancel pending setup for superseded HUDs/switchers and radial widgets owned by an obsolete player, while preserving readiness retries for current owners.
- Refresh indicator restoration baselines when the game or another mod changes their action before rewiring.
- Add targeted behavior regressions. No new timer or per-frame work; native gameplay/FPS validation remains pending.

## 0.3.58

- Allow individual or all slots to be unbound without preventing other shortcuts from initializing; retained actions can be rebound later.
- Restore the latest native bindings after Controls changes, reconciling mapping identity after insertion, reordering or removal, including multiple mappings per action.
- Clear previous-world dialogue and visibility input gates before travel while preserving new-world notifications.
- Prune dead native-indicator restoration records during setup, preserving valid HUD records and avoiding extra work on already-connected indicators.
- Regression coverage includes empty slots, mapping edits/reordering/removal/reload, travel gates and 100 HUD replacements. No new polling or per-frame work. Native gameplay and FPS acceptance remain pending.

## 0.3.57

- Rewrite both distributed READMEs for players, emphasizing dedicated shortcuts, Tap/Hold and optional wheel visibility.
- Apply the new READMEs throughout the Git history while preserving development commits and code changes. Commit IDs have changed; previous release downloads are retired.
- Gameplay behavior and known issues from 0.3.56 are unchanged.

## 0.3.56

- Always suppress conflicting native Quickslot and wheel-swap bindings while enabled; remove the separate menu option and ignore its legacy config value.
- Retain native mapping restoration when disabling the whole mod.
- Verified with 22 Lua suites, 12 runtime syntax checks, 19 Python tests, DMM metadata integration and configuration migration checks.
- Known issues remain: an unbound slot can prevent all shortcuts from initializing; suppression restoration can use stale keys or fail after mapping reordering; travel may retain input-blocking state; indicator restoration records can accumulate. Native gameplay and FPS acceptance are unverified for this release.

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
