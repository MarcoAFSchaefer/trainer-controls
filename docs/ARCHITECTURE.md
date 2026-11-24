# Architecture

```
trainer_controls/
  main.lua    actions, bindings, the input hooks, the Desk panel, the API for other mods
  field.lua   field shortcuts through the game's own menu paths
  ui.lua      the list: screen over the game and Trainer Desk panel
  i18n.lua, lang/, fonts/
```

## Inputs and actions

An input is a token: `key:<name>`, `mouse:<n>`, `wheel:up|down`, `pad:<name>` (SDL button names, `triggerleft`/`triggerright`, `ls_*`/`rs_*` for stick directions, `raw<N>` for unnamed buttons). An action has an id, a kind (`hold` a game button, `tap`, or `field`) and four slots (1-2 keyboard/mouse, 3-4 gamepad).

`bindings[action][slot] = token` is saved in the mod cache as `bindings/v1` (one `action slot token` per line). Two indexes are built from it, `field` and `general`: token to action. A press looks in `field` first when the player is on the map with nothing open, then in `general`.

## Reading the devices

| Hook | What the mod does |
| --- | --- |
| `input.key` | Known keys are answered here and not passed on. The game's own default keys (and the ones added in its CONTROLS menu) are swallowed even when unbound; any other key goes on to the game. |
| `input.gamepad` | Every button event is answered here. Trigger axes become presses at 0.4 / releases at 0.2; stick axes at 0.5 / 0.3. |
| `input.step` | Unnamed gamepad buttons are polled by number; a field shortcut pressed mid-step is retried; the capture timeout. |
| `input.pointer`, `input.wheel` | Bound mouse buttons and wheel directions, behind Trainer Desk (priority 1500 against its 2000). |

Game buttons are held with `Input:sourcePress(btn, "trainer_controls:<token>")` and released with `sourceRelease`, so several inputs on one button behave like the game's own multi-source bookkeeping. Speed uses `Game3:_cycleSpeed`, the other functions `Game3:_hotkey` with the key the game expects.

While the game's own capture is armed (`input.captureArmed`, its CONTROLS menu), every hook passes events through untouched.

## The screen

`ui.lua` keeps one state (selected cell, scroll, the pending capture) for both presentations. `UI.draw(w, h, overlay)` lays the list out for any size; hit rectangles are recorded while drawing. While the screen is open, events are turned into navigation by fixed tables (`NAV_KEYS`, `NAV_PAD`); while a cell waits, the next token of the cell's device kind is bound (`UI.captured`).

## API for other mods

`mod.exports.controls` = `{ api = 1, register(def), unregister(id), open(), isOpen() }`. Registered actions join the "Mods" group; bindings are kept by id even while the action is not registered.
