# Changelog

## 0.2.1

- Shortcuts for what is in front of you (Cut, Rock Smash, Surf, Waterfall, Strength) may share one input without conflict: the one that fits what you are facing is used. Any other two field shortcuts on one input are still a conflict, and are tried in list order.

## 0.2.0

- **Remove** button while a cell waits for an input: empties the cell without pressing anything (Clear, Y and Del still work on the chosen cell).
- **Conflicts are shown, not resolved silently.** Giving an input to an action no longer takes it from another. When two actions that can happen in the same place share an input, both cells are marked in red, the note under the list names the other action and the title shows the count. Field shortcuts (map only) and L/R (menus and battles only) never meet, so R1 = Cut and R is no conflict; R2 = Bicycle and Speed up is one.

## 0.1.0

- First version: game buttons, game functions and field shortcuts mapped on keyboard, mouse and gamepad; controls screen (F8) and Trainer Desk panel; PlayStation, Xbox and Nintendo button names; actions from other mods.
- Replaces `pad_shortcuts`, adding Rock Smash, Waterfall, Dig and Sweet Scent.
- English, Spanish, Portuguese and Japanese.
