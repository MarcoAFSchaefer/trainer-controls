-- Checks for Trainer Controls: a stand-in game input that records what is
-- pressed, raw events sent through the hooks, and the screen drawn in two sizes.
local OUT = os.getenv("TEST_OUT") or "/tmp/controls_out"
local DIR = os.getenv("CONTROLS_MOD")
local G = love.graphics
local function reader(dir) return function(name) local f = io.open(dir .. "/" .. name, "rb"); if not f then return nil end; local s = f:read("*a"); f:close(); return s end end
function love.errorhandler(msg) print("HARNESS ERROR", msg, debug.traceback()); return function() return 1 end end
local function check(cond, msg) if not cond then error("CHECK FAILED: " .. msg, 2) end; print("ok  " .. msg) end

function love.load()
  os.execute("mkdir -p " .. OUT)
  local clock = 0
  love.timer.getTime = function() return clock end
  local overworld, used, facing = true, {}, nil
  package.preload["src.core.game3.field"] = function() return { running = true, _session = { bag = { [360] = 1 }, party = {} } } end
  package.preload["src.ui.game3.hud"] = function() return { busy = function() return not overworld end } end
  package.preload["src.core.game3.player"] = function() return { moving = false } end
  package.preload["src.core.game3.bag"] = function() return { has = function(bag, id) return (bag[id] or 0) > 0 end } end
  package.preload["src.core.game3.item_use"] = function() return { useField = function(_, _, id) used[#used + 1] = id; return true end } end

  local held, log = {}, {}
  local input = { keyBindings = {}, captureArmed = false,
    sourcePress = function(_, btn, source) held[btn] = source; log[#log + 1] = "+" .. btn end,
    sourceRelease = function(_, btn, source) if held[btn] == source then held[btn] = nil end; log[#log + 1] = "-" .. btn end }
  local game = { input = input, hot = {}, speed = 0 }
  function game:_hotkey(key) self.hot[#self.hot + 1] = key; return true end
  function game:_cycleSpeed(dir) self.speed = self.speed + dir end

  local panels, cache, warns = {}, {}, {}
  local dock = { exports = { dock = { api = 1, active = function() return true end,
    register = function(def) panels[def.id] = def end, unregister = function(id) panels[id] = nil end,
    theme = function() return { colors = {} } end } } }
  local function newMod()
    local read = reader(DIR)
    local mod = { id = "trainer_controls", generation = 3, options_ = {}, hooks_ = {}, events_ = {}, exports = {} }
    mod.read = function(_, n) return read(n) end
    mod.options = { define = function(_, s) for _, row in ipairs(s) do if mod.options_[row.key] == nil then mod.options_[row.key] = row.default end end
      if os.getenv("TEST_LANG") then mod.options_.language = os.getenv("TEST_LANG") end end,
      get = function(_, k) return mod.options_[k] end }
    mod.hooks = { wrap = function(_, n, f) mod.hooks_[n] = f end }
    mod.events = { on = function(_, n, f) mod.events_[n] = f end }
    mod.log = { warn = function(_, f, ...) warns[#warns + 1] = f:format(...); print("WARN", warns[#warns]) end }
    mod.cache = { read = function(_, k) return cache[k] end, write = function(_, k, v) cache[k] = v; return true end }
    mod.find = function(id) return id == "trainer_desk" and dock or nil end
    assert(loadstring(read("main.lua"), "@trainer_controls/main.lua"))()(mod)
    return mod
  end
  local mod = newMod()
  mod.events_["game.ready"]({ game = game })
  local passed = 0
  local function nextHook() passed = passed + 1 end
  local function key(k, phase) local before = passed; mod.hooks_["input.key"](nextHook, game, { phase = phase or "pressed", key = k }); return passed > before end
  local function pad(b, phase) local before = passed; mod.hooks_["input.gamepad"](nextHook, game, { phase = phase or "pressed", button = b }); return passed > before end
  local function axis(a, v) mod.hooks_["input.gamepad"](nextHook, game, { phase = "axis", axis = a, value = v }) end
  local function mouse(b, phase, x, y) local before = passed; mod.hooks_["input.pointer"](nextHook, game, { phase = phase or "pressed", source = "mouse", button = b, x = x or 0, y = y or 0 }); return passed > before end
  local function wheel(dy) local before = passed; mod.hooks_["input.wheel"](nextHook, game, dy); return passed > before end
  local function step() mod.hooks_["input.step"](function() end, game, 1 / 60); mod.hooks_["core.update"](function() end, game, 1 / 60) end
  local D = mod.exports.debug
  local UI = D.ui

  -- defaults: the game's buttons from the keyboard and the gamepad
  check(not key("z") and held.a ~= nil, "Z holds A")
  check(not key("z", "released") and held.a == nil, "letting go releases it")
  key("up"); key("w"); key("up", "released")
  check(held.up ~= nil, "two keys on one button: it stays held while one is down")
  key("w", "released"); check(held.up == nil, "and is released with the last")
  pad("a"); check(held.a ~= nil, "gamepad A holds A"); pad("a", "released")
  check(pad("leftshoulder") == false and held.l ~= nil, "L1 holds L and the game does not see the raw button"); pad("leftshoulder", "released")
  axis("leftx", -0.8); check(held.left ~= nil, "the left stick pushes Left")
  axis("leftx", -0.4); check(held.left ~= nil, "and holds until it is back near the middle")
  axis("leftx", 0); check(held.left == nil, "then lets go")
  axis("triggerright", 0.9); check(game.speed == 1, "R2 speeds up, once per pull")
  axis("triggerright", 0.95); check(game.speed == 1, "not again while held"); axis("triggerright", 0)
  key("f1"); key("f1", "released"); check(game.hot[1] == "f1", "F1 quick saves")
  check(not key("space") and held.a == nil, "a game key with no action here does nothing (Space)")
  check(key("f11"), "a key nobody knows goes on to the game")
  input.captureArmed = true
  check(key("z") and held.a == nil, "while the game's own CONTROLS menu listens, events are left alone")
  input.captureArmed = false

  -- rebinding: nothing is taken away; what clashes is reported
  check(D.assign("b", 1, "key:z")[1] == "a" and D.conflictCount() == 1, "Z given to B clashes with A, and is counted")
  check(D.conflicts("a", 1)[1] == "b", "seen from both sides")
  key("z"); check(held.a ~= nil and held.b == nil, "of two that clash, the first in the list answers"); key("z", "released")
  D.clear("a", 1); check(D.conflictCount() == 0, "removing one ends the conflict")
  key("z"); check(held.b ~= nil and held.a == nil, "Z now holds B"); key("z", "released")
  check(cache["bindings/v1"]:find("\nb 1 key:z\n", 1, true) and not cache["bindings/v1"]:find("\na 1 ", 1, true), "saved")
  -- field shortcuts: their own context
  check(#D.assign("bike", 3, "pad:rightshoulder") == 0 and D.bindings().r[3] == "pad:rightshoulder", "R1 for the Bicycle and for R is no conflict: they never meet")
  check(D.assign("surf", 3, "pad:triggerright")[1] == "speed_up", "R2 for Surf and for Speed up is one: both can happen on the map")
  check(D.assign("fly", 3, "pad:triggerright")[1] ~= nil and D.conflictCount() == 3, "two field shortcuts that can both apply clash too")
  D.clear("surf", 3); D.clear("fly", 3)
  -- Cut and Rock Smash act on what is in front: one button for both, the one that fits is used
  check(#D.assign("cut", 3, "pad:x") == 0 and #D.assign("rock_smash", 3, "pad:x") == 0 and D.conflictCount() == 0, "Cut and Rock Smash on one button is no conflict")
  local asked = {}
  package.loaded["src.core.game3.field"].executeFieldMove = function(res) asked[#asked + 1] = "used " .. res.name end
  package.loaded["src.core.game3.field_moves"] = { partyMoveUser = function() return {} end,
    fromMenu = function(name) asked[#asked + 1] = name; return { ok = name == facing, name = name } end }
  facing = "ROCK_SMASH"; pad("x"); pad("x", "released")
  check(asked[#asked] == "used ROCK_SMASH", "facing a rock, the shared button smashes it: " .. table.concat(asked, ","))
  asked = {}; facing = "CUT"; pad("x"); pad("x", "released")
  check(asked[#asked] == "used CUT", "facing a tree, it cuts")
  asked = {}; facing = nil; pad("x"); pad("x", "released")
  check(#asked == 2, "facing nothing, nothing is used")
  D.clear("cut", 3); D.clear("rock_smash", 3); package.loaded["src.core.game3.field_moves"] = nil
  overworld = true; pad("rightshoulder"); pad("rightshoulder", "released")
  check(#used == 1 and used[1] == 360 and held.r == nil, "on the map R1 rides the Bicycle")
  overworld = false; pad("rightshoulder")
  check(#used == 1 and held.r ~= nil, "in a menu R1 is R"); pad("rightshoulder", "released")
  overworld = true
  -- mouse and wheel
  check(mouse(2) == true, "an unbound mouse button goes on")
  D.assign("b", 2, "mouse:2"); check(mouse(2) == false and held.b ~= nil, "right click bound to B holds B")
  mouse(2, "released"); check(held.b == nil, "released with the button")
  D.assign("speed_down", 2, "wheel:down"); check(wheel(-1) == false and game.speed == 0, "the wheel can slow the game down")
  check(wheel(1) == true, "the other wheel direction is still the game's")
  -- another mod's action
  local api, ran = mod.exports.controls, 0
  check(api.api == 1 and api.register({ id = "demo.go", label = "Demo", run = function() ran = ran + 1 end }), "another mod registers an action")
  check(api.register({ id = "a", run = function() end }) == false, "it cannot replace one of ours")
  D.assign("demo.go", 1, "key:g"); key("g"); key("g", "released"); check(ran == 1, "and it runs from its key")
  api.unregister("demo.go"); check(key("g") == true and ran == 1, "unregistered: its key is nobody's again"); key("g", "released")

  -- the screen
  key("f8"); key("f8", "released"); check(UI.isOpen(), "F8 opens the controls screen")
  key("z"); check(held.b == nil, "while it is open the game gets nothing"); key("z", "released")
  check(UI.capturing(), "Z (select) on a cell waits for an input")
  key("k"); key("k", "released")
  check(not UI.capturing() and D.bindings().up[1] == "key:k", "the next key goes in the cell: Up is K")
  key("right"); key("right"); key("return")
  key("j"); check(UI.capturing(), "a key is no answer for a gamepad cell")
  pad("x"); check(not UI.capturing() and D.bindings().up[3] == "pad:x", "a gamepad button is")
  pad("x", "released")
  pad("a"); pad("a", "released"); check(UI.capturing(), "gamepad A selects too")
  clock = clock + 7; step(); check(not UI.capturing() and D.bindings().up[3] == "pad:x", "nothing pressed: the wait ends with no change")
  pad("y"); check(D.bindings().up[3] == nil, "Y clears the cell"); pad("y", "released")
  local lang = os.getenv("TEST_LANG") or "en"
  local function shot(name, w, h, overlay)
    local c = G.newCanvas(w, h)
    G.setCanvas(c); G.clear(0.3, 0.5, 0.3, 1)
    local depth = G.getStackDepth()
    if overlay then mod.hooks_["render.hud"](function() end, game, { gameX = 0, gameY = 0, gameWidth = w, gameHeight = h, scale = w / 240 })
    else panels["trainer_controls.controls"].draw(0, w, h) end
    check(G.getStackDepth() == depth, "stack balanced: " .. name)
    G.setCanvas()
    local f = io.open(OUT .. "/" .. name .. "-" .. lang .. ".png", "wb"); f:write(c:newImageData():encode("png"):getString()); f:close()
  end
  shot("screen", 720, 480, true)
  for _ = 1, 12 do key("down"); key("down", "released") end
  mod.options_.pad_labels = "playstation"
  shot("screen-scrolled", 720, 480, true)
  key("return"); shot("screen-waiting", 720, 480, true); clock = clock + 7; step()
  -- reset asks twice
  key("r"); key("r", "released"); check(D.bindings().up[1] == "key:k", "Defaults asks first")
  key("r"); key("r", "released"); check(D.bindings().up[1] == "key:up" and D.bindings().bike == nil, "and then puts everything back")
  key("escape"); check(not UI.isOpen(), "Esc closes the screen"); key("escape", "released")
  check(held.start == nil, "and its release does not reach the game")
  -- the panel in Trainer Desk
  step()
  local panel = panels["trainer_controls.controls"]
  check(panel ~= nil and panel.pointer ~= nil, "the panel is docked")
  shot("panel", 480, 432, false)
  shot("panel-narrow", 320, 560, false)
  panel.draw(0, 480, 432)
  local sx = 480 - 10 - 4 * 76 - 3 * 4
  panel.pointer("down", sx + 10, 42 + 20 + 8)   -- first action row (after the heading), first cell
  check(UI.capturing() and not UI.isOpen(), "a click on a cell in the panel waits for an input")
  key("i"); key("i", "released"); check(D.bindings().up[1] == "key:i", "and takes the key")
  panel.draw(0, 480, 432); panel.pointer("down", sx + 10, 42 + 20 + 8); panel.draw(0, 480, 432)
  check(mouse(3) == false and D.bindings().up[1] == "mouse:3", "a click on the game while waiting binds that mouse button")
  mouse(3, "released")
  -- removing without pressing anything
  panel.draw(0, 480, 432); panel.pointer("down", sx + 10, 42 + 20 + 8); panel.draw(0, 480, 432)
  panel.pointer("down", 240, 414)
  check(not UI.capturing() and D.bindings().up[1] == nil, "Remove, while a cell waits, empties it")
  D.assign("up", 1, "mouse:3")
  -- a conflict on screen
  D.assign("surf", 3, "pad:triggerright"); panel.draw(0, 480, 432)
  shot("panel-conflict", 480, 432, false)
  D.clear("surf", 3)
  -- with no input left for the screen, F8 still opens it
  D.clear("controls_menu", 1)
  key("f8"); check(UI.isOpen(), "F8 opens the screen even when unbound"); key("f8", "released"); UI.close()
  -- a fresh load reads what was saved
  local again = newMod()
  check(again.exports.debug.bindings().up[1] == "mouse:3", "bindings survive a restart")
  check(#warns == 0, "nothing was logged")
  print("ALL CONTROLS CHECKS PASSED")
  love.event.quit(0)
end
