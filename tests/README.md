# Tests

`tests/main.lua` is a LÖVE program with a stand-in game input. It sends raw key, gamepad, mouse and wheel events through the mod's hooks and checks what reaches the game, rebinding, the screen and the panel, and saves screenshots.

```
cd tests
CONTROLS_MOD=../trainer_controls TEST_LANG=en xvfb-run -a -s "-screen 0 1280x800x24" love .
```

Screenshots go to `TEST_OUT` (default `/tmp/controls_out`). The run ends with `ALL CONTROLS CHECKS PASSED`.
