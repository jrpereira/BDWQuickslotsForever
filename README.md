# QuickslotsForever for The Blood of Dawnwalker

Combat demands your attention. Switching between Abilities and Consumables
interrupts that focus: before making your next move, you have to check which
wheel is active.

QuickslotsForever gives you **dedicated shortcuts for all four Abilities and all
four Consumables**, respecting the game's Day/Night cycle. Reach straight for
what you need, without switching wheels.

**A short tap and a long press can give the same key two uses.** Tap **Q** to
drink a vial of animal blood; hold **Q** to drink human blood. Eight slots at your
fingertips, with fewer keys to remember.

Both wheels are visible by default, keeping your options in sight. Prefer a
quieter HUD? You can show just one wheel at a time and still use every dedicated
shortcut.

## What you can change

- Show both wheels together, or keep the game's single-wheel layout.
- Choose a key and Tap or Hold for each of the four ability and four consumable slots.
- Move each wheel and swap their positions through the mod menu.
- Adjust how long a press must last to count as Hold.

Your shortcuts work independently of which wheel is visible.

## Requirements

- The Blood of Dawnwalker on Windows, with a compatible UE4SS installation.
- [UE4SSLuaEventBridge](https://github.com/jrpereira/UE4SSLuaEventBridge), API 4.
- Optional: Dawnwalker Mod Menu to change settings in-game.
- Optional: [ModMenuDecorator](https://github.com/jrpereira/BDWModMenuDecorator)
  to choose keys by pressing them and use paired Tap/Hold controls in the menu.

Install these separately; the download contains QuickslotsForever only.

## Install or upgrade

1. Close the game. If upgrading, back up your existing `config.ini`.
2. Extract the ZIP and copy its `QuickslotsForever` folder into `ue4ss/Mods`.
   Keep that folder name and install only one copy of the mod.
3. For a fresh installation, copy `config.example.ini` to `config.ini` inside
   the QuickslotsForever folder.
4. When upgrading, keep your existing `config.ini` and mod enablement settings.
   Replacing your configuration with the example resets your choices.
5. Start the game and load your save.

### Upgrading an older wheel configuration

If your older configuration is missing Show Both Wheels, enable Show Both in the
mod menu and select Apply Changes. Keep your other settings and existing shortcuts.

If editing the file manually, back up `config.ini`, then add `ShowBothWheels=1`
under `[General]` only if that setting is missing. Preserve any existing On/Off
choice. Fresh installations using the example configuration do not need this step.

## Choose your shortcuts

Open **Mod Settings → QuickslotsForever**, choose a key and Tap/Hold mode for each
slot, then select **Apply Changes**. Presets and edits take effect after Apply.

With ModMenuDecorator installed, click a key control and press the key you want.
Without it, the menu uses numeric key values and separate Tap/Hold choices.
You can also edit `config.ini` with the game closed: keys use Windows virtual-key
numbers (for example, Q is `81`); `0` leaves a slot unbound. Modes are `0`
for Tap or `1` for Hold.

The default Hold threshold is **200 ms**. A short press activates Tap; holding
past the threshold activates Hold once. You can assign the same key to two slots
by giving one Tap and the other Hold.

### Default shortcuts

A fresh installation uses the **Reduced** preset:

| Slot | Shortcut |
| --- | --- |
| Ability 1 | R — Tap |
| Ability 2 | R — Hold |
| Ability 3 | T — Tap |
| Ability 4 | T — Hold |
| Consumable 1 | 1 — Tap |
| Consumable 2 | 2 — Tap |
| Consumable 3 | Q — Tap |
| Consumable 4 | Q — Hold |

You can also choose **Vanilla** or **Numbers**, or make your own combination.
Changes that do not match a preset appear as **Custom**. Upgrading preserves your
saved choices.

## Arrange the wheels

Turn on **Show both Abilities and Consumables shortcut wheels** to see both at
once and reveal the **Wheels** settings. Use the Abilities and Consumables X/Y
settings to move them, or **Swap Abilities with Consumables** to exchange their
positions. Swapping positions does not change which slots your shortcuts use.

Turn Show Both off to return to the game's single-wheel layout. Your configured
ability and consumable shortcuts still work.

Conflicting original Quickslot and wheel-swap bindings are disabled automatically
while the mod is enabled, so a press does not also trigger a conflicting original
action. Wheel positions are swapped through the mod menu. Disabling the mod
restores the original bindings; your saved choices in the game's Controls menu
are not edited.

## Assign consumables in Inventory

Use the usual **S** assignment overlay, then **1–4**, the arrow keys, or the
corresponding D-pad directions to choose a slot. Assignment uses these fixed
inputs, so you do not have to hold a gameplay shortcut to assign an item.

## Troubleshooting

- **Shortcuts do not respond:** load a save, check that the mod is enabled, and
  confirm UE4SSLuaEventBridge is installed with the required API version.
- **A menu edit does not stick:** select Apply Changes, then reopen the page to
  check that your choice was saved.
- **Wheel position settings are missing:** turn on Show Both. For an older
  configuration missing that setting, follow the upgrade steps above.
- **After an upgrade:** fully restart the game before trying the new version.

Unsupported key choices are rejected without replacing your working shortcuts.
If the log reports ambiguous native mappings after another mod changes Controls,
restart the game to reload native mappings before retrying.


To report a problem, include your game, UE4SS, QuickslotsForever, bridge and menu
mod versions, the affected shortcut, and the steps that caused it. Attach
`ue4ss/UE4SS.log` when possible. For a crash, also keep the game's crash report.
Review logs before sharing them publicly, as they may contain personal file paths.
