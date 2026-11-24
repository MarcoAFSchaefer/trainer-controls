# Trainer Controls: player guide

## First steps

1. Copy `trainer_controls` into `%APPDATA%\pokemon-love2d\mods` and turn it on. If you used `pad_shortcuts`, turn that one off.
2. In the game, press **F8**. The controls screen opens over the game.
3. Move to a cell, press A / Enter (or click it), then press the key or button you want there.

Out of the box the controls are the game's usual ones: arrows or WASD, Z / Enter for A, X / Backspace for B, Esc for START, Tab for SELECT, Q and E for L and R; on a gamepad the D-pad or left stick, the face buttons, the shoulders for L and R and the triggers for speed. Field shortcuts start empty.

## The list

Each row is an action; the first two cells are for keyboard and mouse, the last two for the gamepad.

- **Game buttons** are held while the key is held.
- **Game functions** happen once per press.
- **Field shortcuts** work while you walk on the map and do what the Pokémon menu or the Bag would: Cut needs the badge, a Pokémon that knows Cut and a tree in front of you. Because they only act on the map, they may share a button with something else: put Cut on R1 and R1 still is R in the Bag.
- **Mods**: the controls screen, and actions other mods add.

To empty a cell: choose it and press Clear (Y on the gamepad, Del on the keyboard), or press **Remove** while it waits for an input.

## Conflicts

An input may be given to more than one action. That is fine when the two can never happen in the same place: field shortcuts only act on the map, L and R only in menus and battles, so R1 can be Cut and R. When both can happen in the same place (R2 as Bicycle and as Speed up: both on the map), it is a conflict: the cells are outlined in red with a "!", the note under the list names the other action, and the title shows how many there are. Only one of the two answers (a field shortcut first on the map; otherwise the one higher in the list), so remove or change one of them.

## Mouse and special inputs

- While a keyboard/mouse cell waits: right, middle and side buttons are taken when clicked; the wheel when turned; for the left button use **Use left click**.
- Triggers and stick directions are bound like buttons: pull or push them while a gamepad cell waits.
- The DualSense touchpad click and other buttons without a standard name appear as **Extra N**.

## If something goes wrong

- **Defaults** (pressed twice) puts everything back.
- F8 opens the screen whenever nothing at all is bound to it.
- The screen's own keys never change: arrows, Enter, Esc, Del on the keyboard; D-pad, A, B, Y on the gamepad.
