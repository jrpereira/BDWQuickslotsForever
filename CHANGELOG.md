# Version history

Use the latest release for current fixes. Historical releases retain the behavior and limitations described below.

## 0.3.69

- Reacquire retained Enhanced Input contexts and actions before reusing invalid object proxies.
- Initialize persistent action identity once per valid acquisition and validate its reflected library dependency.
- Keep Direct groups before Selective in the settings hierarchy and retain unconditional access to both sections.

## 0.3.68

- Rename Independent interaction to Direct without changing its saved numeric value.
- Gate native wheel Swap in both interaction modes.
- Preserve the four native slot actions in Selective.

## 0.3.67

- Gate conflicting native Input Actions directly without modifying mappings or saved keys.
- Restore directional Quickslot actions while the Inventory assignment overlay is active.
- Remove mapping journals, Controls-remap transactions and context-mutation hooks.

## 0.3.66

- Add separate Size and Opacity controls for Primary and Secondary wheels.
- Present Primary and Secondary visual controls in Level 4 subsections with concise field labels.

## 0.3.65

- Replace the former three interaction choices with Independent and Selective.
- Let Selective use the game's four native Quickslot bindings while the mod controls wheel focus.
- Support a Secondary Wheel key as either Tap Trigger or Hold Sustained, returning to Primary on release.
- Keep the configured Primary wheel in the native switcher and exchange switcher ownership when Selective changes focus.
- Leave the native two-wheel hierarchy untouched when only one wheel is displayed.

## 0.3.64

- Make Primary Wheel the sole wheel-role selection; ignore obsolete positional swap when primary is explicit.
- Read the edited One/Two display and primary/secondary position settings, keeping legacy configuration fallback.
- Place position settings and the global threshold under More Options; align interaction labels with their input behavior.

- Use one global Hold threshold for both wheels and preserve the existing configured value.
- Remove wheel-specific threshold controls; obsolete configuration entries are ignored.

## 0.3.63

- Add Alt or Nothing, Tap Tap and Independent interaction modes with conditional controls.
- Select the actual primary wheel.
- Preserve existing shortcuts.
- Cancel shared presses on wheel changes and stale queued input on menu/lifecycle changes.
- Use canonical Deco metadata for tabs, header promotion, dynamic slot labels and fixed modes.
- Require native delivery-fault protection for Alt and check modifier state before activation.

## 0.3.62

- Remove development and migration tools from the installable ZIP.
- Reject Tools directories at every nesting level, regardless of capitalization.
- Explain older wheel configuration upgrades through the mod menu or a manual configuration edit.
- Keep gameplay behavior unchanged from 0.3.61.

## 0.3.61

- Remove unused routing calculations from input recovery.
- Preserve gameplay context repair and the initialization routing log.

Ambiguous external edits to suppressed duplicate mappings retain recovery records rather than guessing keys; a native Controls reset may be needed.

## 0.3.60

- Complete interrupted restoration on direct retries without losing native settings behavior.
- Match known duplicate mappings one-to-one and retain recovery records for ambiguous edits.
- Prune dead completed wheel-setup records during new setup.

Ambiguous external edits to suppressed duplicate mappings retain recovery records rather than guessing keys; a native Controls reset may be needed.

## 0.3.59

- Validate key choices before replacing working bindings and add missing standard keyboard keys.
- Restore native mappings before Controls edits, then reconcile suppression.
- Cancel obsolete HUD setup and preserve external changes to indicator actions.

Ambiguous external edits to suppressed duplicate mappings retain recovery records rather than guessing keys; a native Controls reset may be needed.

## 0.3.58

- Allow unbound slots without blocking the remaining shortcuts.
- Reconcile native restoration after Controls edits and mapping reordering.
- Clear stale input gates on travel and prune dead indicator records.

## 0.3.57

- Explain dedicated shortcuts, Tap/Hold and optional wheel visibility in player-facing documentation.
- Keep gameplay behavior unchanged from 0.3.56.

Known limitations: unbound slots can prevent shortcut initialization; restoration after mapping edits and travel-state handling are improved in later versions.

## 0.3.56

- Always suppress conflicting native Quickslot and wheel-swap bindings while the mod is enabled.
- Remove the suppression checkbox and ignore its legacy configuration value.
- Restore native mappings when the mod is disabled.

Known limitations: unbound slots can prevent shortcut initialization; restoration after mapping edits and travel-state handling are improved in later versions.

## 0.3.55

- Preserve existing mod enablement during deployment; never create an enablement marker automatically.
- Tighten public repository rules while retaining ordinary regression tests.

Known limitations: unbound slots can prevent shortcut initialization; restoration after mapping edits and travel-state handling are improved in later versions.

## 0.3.54

- Remove weapon controls and the unrelated menu section.
- Focus the mod on ability and consumable shortcuts, wheels and conflicting native bindings.
- Use a fresh game process when upgrading; existing runtime mappings are not hot-migrated.

Known limitations: unbound slots can prevent shortcut initialization; restoration after mapping edits and travel-state handling are improved in later versions.

## 0.3.53

- Preserve subscriptions on routing-only changes and rebind when the owner or configuration changes.
- Use scoped inventory navigation, cached targets and separate indicator/layout setup.
- Bound recovery work and retain obligations after failed mapping rebuilds.

## 0.3.52

- Cache shortcut targets and preserve input subscriptions on routing-only changes.
- Prepare fixed-key assignment from Inventory navigation while keeping the mapping scoped to the S overlay.

## 0.3.51

- Order wheel formats as single, consumables above abilities, and abilities above consumables.
- Keep indicator setup separate from layout updates.

## 0.3.50

- Separate one-time indicator wiring from idempotent wheel formatting.
- Apply layout changes without rewiring completed indicators.

## 0.3.49

- Prepare wheel indicators after relevant widget creation.
- Stop setup after completion; retry only while required children are missing from a valid owner.

## 0.3.48

- Replace idle recovery polling with lifecycle-triggered work and bounded retries.
- Remove the configuration-file watcher.

## 0.3.47

- Keep the assignment mapping attached while the S overlay is inactive so native activation paths can use it.
- Restore the original overlay priority on disable or travel.

## 0.3.46

- Use a retained high-priority input context for inventory assignment.
- Map native slot actions to fixed number and directional keys while the S overlay is active.

## 0.3.45

- Reuse retained input actions across shortcut binding changes.
- Wire native HUD and floating-wheel indicators to mod actions.

## 0.3.44

- Retain dedicated mod input actions and connect native key indicators to them.
- Separate persistent input, action indicators and native mapping suppression into modules.

## 0.3.41

- Restore native-style shortcut icons and cache their presentation.
- Keep gameplay shortcuts separate from inventory assignment.

## 0.3.38

- Separate inventory assignment from gameplay consumable callbacks.
- Use fixed 1–4 or directional keys while the S assignment overlay is active, independently of gameplay Hold settings.

## 0.3.37

- Run input lifecycle checks through the guarded HUD maintenance queue.
- Handle input and HUD failures independently.

## 0.3.36

- Cache wheel and prompt object paths and avoid unchanged layout writes.
- Invalidate discovery caches when relevant widgets are created.

## 0.3.35

- Replace recursive HUD scheduling with a guarded 500 ms maintenance loop.
- Keep one queued game-thread update and recover after callback errors.
- Inventory assignment remains unresolved in this historical version.

## 0.3.34

- Queue swap-prompt creation refreshes on the game thread.
- Retain the preceding wheel layout and gameplay bindings.

## 0.3.33

- Coalesce HUD recovery and skip redundant wheel updates.
- Keep gameplay bindings when only visual settings change.
- Inventory assignment remains unresolved in this historical version.

## Earlier development

The original shortcut and wheel implementation remains in Git history. Incomplete or conflicting snapshots are not listed as final releases.
