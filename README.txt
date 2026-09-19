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
- Choose Consumables or Abilities as your primary wheel and adjust both positions.
- Adjust how long a press must last to count as Hold.

In Independent mode, your shortcuts work regardless of which wheel is visible.

## Requirements

- The Blood of Dawnwalker on Windows, with a compatible UE4SS installation.
- [UE4SSLuaEventBridge](https://github.com/jrpereira/UE4SSLuaEventBridge), API 4.
  Use the latest version for Selective Hold.
- Optional: Dawnwalker Mod Menu to change settings in-game.
- Optional: [ModMenuDecorator](https://github.com/jrpereira/BDWModMenuDecorator)
  to choose keys by pressing them and use paired Tap/Hold controls in the menu.
  Use version **0.1.43 or newer** when upgrading older configurations through the menu.

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

Existing configuration files remain supported. **Wheels Displayed** selects
**One** or **Two** in the mod menu. When editing the file manually, use
`ShowWheels=1` or `ShowWheels=2` under `[General]`. If absent, the mod still
reads the older `ShowBothWheels` choice. Back up your configuration before editing.

## Choose your shortcuts

Open **Mod Settings → QuickslotsForever**, choose a key and Tap/Hold mode for each
slot, then select **Apply Changes**. Edits take effect after Apply.

With ModMenuDecorator installed, click a key control and press the key you want.
Without it, the menu uses numeric key values and separate Tap/Hold choices.
You can also edit `config.ini` with the game closed: keys use Windows virtual-key
numbers (for example, Q is `81`); `0` leaves a slot unbound. Modes are `0`
for Tap or `1` for Hold.

The default Hold threshold is **200 ms**. A short press activates Tap; holding
past the threshold activates Hold once. You can assign the same key to two slots
by giving one Tap and the other Hold. In **More Options**, **Hold threshold** sets this duration globally, regardless
of the wheel. Your existing threshold is preserved when upgrading.

### Interaction

- **Independent:** keep a dedicated shortcut for every ability and consumable.
  Primary slots are numbered 1–4; secondary slots are numbered 5–8. Existing
  bindings stay attached to their abilities or consumables when you change primary.
- **Selective:** use the four Quickslot keys configured in the game's Controls
  menu on whichever wheel is selected. The Secondary Wheel key uses **Hold** by
  default: hold it to select Secondary, then release it to return to Primary.
  Choose **Tap** to use separate keys that select Secondary and Primary.

Independent remains the default. Changing interaction modes preserves the keys
and choices you saved for the other mode. A slot Hold is a discrete action after
a charge-up. Selective Hold is sustained: it remains active exactly while the key
is pressed and does not use the slot Hold threshold.

### Default shortcuts

A fresh installation uses these shortcuts:

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
Upgrading preserves your saved shortcuts.

## Arrange the wheels

Set **Wheels Displayed** to **Two** to see both at once. Choose Consumables or
Abilities as your **Primary Wheel**. Use **Primary X/Y** and **Secondary X/Y**
in **More Options**, at the bottom of the page, to adjust their positions.
The primary position starts lower, with the secondary above it. Changing primary
exchanges the wheels between those positions without changing their shortcuts.

Choose **One** to keep the native single-wheel layout. Selective changes which
wheel is shown; Independent shortcuts continue to address either wheel directly.

Conflicting original Quickslot and wheel-swap bindings are disabled automatically
while the mod is enabled, so a press does not also trigger a conflicting original
action. Disabling the mod
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
- **Wheel position settings:** open **More Options** at the bottom of the page.
- **After an upgrade:** fully restart the game before trying the new version.

Unsupported key choices are rejected without replacing your working shortcuts.
If the log reports ambiguous native mappings after another mod changes Controls,
restart the game to reload native mappings before retrying.


To report a problem, include your game, UE4SS, QuickslotsForever, bridge and menu
mod versions, the affected shortcut, and the steps that caused it. Attach
`ue4ss/UE4SS.log` when possible. For a crash, also keep the game's crash report.
Review logs before sharing them publicly, as they may contain personal file paths.
