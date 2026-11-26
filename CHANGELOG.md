# Changelog

## 0.4.0

- The controls you set now belong to the save that is open, kept in the game's per-save store for mods; they used to be the same for every save and every open copy of the game. A save with no controls of its own yet starts from the ones there were.

## 0.3.0

- The Controls panel carries the Controls Badge on its tab in Trainer Desk (0.8.0 or newer; older versions just show the title).
- The mod is now part of the **Trainer Badges**: a badge, a banner and the family case in the README.

## 0.2.5

- Mouse clicks on the controls screen land where you click when Trainer Desk is on. The screen took the game picture to start at the window's corner, so with docks around the game every click was read too far to the right and down: Close did nothing and a click on a cell could open another one.
- A fast turn of the mouse wheel scrolls the list by as many rows as it turned, not by one.

## 0.2.4

- The file with the field shortcuts is now `shortcuts.lua` (was `field.lua`), so the mod passes the modkit's `validate --strict`: a file named like one of the game's own data tables is checked as a possible copy of it. Nothing changes in play.

## 0.2.3

- Removing with the keyboard or the gamepad works: choosing a cell (A / Enter) now asks **Change / Remove / Cancel** instead of waiting for an input at once. Before, the wait took the very key meant to remove (Y or Del) as the new binding, so a cell could only be replaced. A mouse click still goes straight to waiting, with Remove and Cancel under the list.

## 0.2.2

- The controls screen warns when the old `pad_shortcuts` mod is still on: it keeps answering the gamepad, so shortcuts removed here would still fire.

## 0.2.1

- Shortcuts for what is in front of you (Cut, Rock Smash, Surf, Waterfall, Strength) may share one input without conflict: the one that fits what you are facing is used. Any other two field shortcuts on one input are still a conflict, and are tried in list order.

## 0.2.0

- **Remove** button while a cell waits for an input: empties the cell without pressing anything (Clear, Y and Del still work on the chosen cell).
- **Conflicts are shown, not resolved silently.** Giving an input to an action no longer takes it from another. When two actions that can happen in the same place share an input, both cells are marked in red, the note under the list names the other action and the title shows the count. Field shortcuts (map only) and L/R (menus and battles only) never meet, so R1 = Cut and R is no conflict; R2 = Bicycle and Speed up is one.

## 0.1.0

- First version: game buttons, game functions and field shortcuts mapped on keyboard, mouse and gamepad; controls screen (F8) and Trainer Desk panel; PlayStation, Xbox and Nintendo button names; actions from other mods.
- Replaces `pad_shortcuts`, adding Rock Smash, Waterfall, Dig and Sweet Scent.
- English, Spanish, Portuguese and Japanese.
