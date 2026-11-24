-- Trainer Controls: every control mapped the way the player wants.
--
-- An *input* is one physical thing that can be pressed, written as a token:
--   key:<name>     a keyboard key, by LÖVE's name            key:z, key:f1
--   mouse:<n>      a mouse button                            mouse:2
--   wheel:up|down  the mouse wheel
--   pad:<name>     a gamepad button, trigger or stick push   pad:a, pad:triggerleft, pad:ls_up, pad:raw14
-- An *action* is something the game does: holding one of its buttons, one of
-- its functions (speed, quick save...), a field shortcut, or something another
-- mod registered. Each action has four slots: two for keyboard and mouse, two
-- for the gamepad.
--
-- The mod reads keyboard, gamepad, mouse and wheel through the input.* hooks,
-- ahead of the game, and answers every input it knows itself; the game's own
-- key and button tables are bypassed (its default keys with no action here do
-- nothing, so removing a control really removes it).
--
-- Every action has the places where it can happen: field shortcuts only on
-- the map, L and R only in menus and battles, the rest everywhere. One input
-- may serve two actions that never meet (R1 for Cut while walking, R in the
-- Bag). Two actions that can happen in the same place on one input are a
-- conflict: it is allowed, shown on the screen, and only one of them answers
-- (a field shortcut before anything else on the map, else the first in the list).
--
-- Bindings are kept in the mod cache (bindings/v1). The controls screen opens
-- over the game (F8 by default) and the same list is a Trainer Desk panel.
return function(mod)
  if mod.generation ~= nil and mod.generation ~= 3 then return end
  local function load_(name, ...)
    return assert(load(assert(mod:read(name)), "@trainer_controls/" .. name))()(...)
  end

  mod.options:define({
    { key = "language", label = "LANGUAGE", type = "choice", default = "en",
      choices = { { "ENGLISH", "en" }, { "ESPANOL", "es" }, { "PORTUGUES", "pt" }, { "JAPANESE", "ja" } },
      description = "Language of the controls screen." },
    { key = "pad_labels", label = "GAMEPAD BUTTON NAMES", type = "choice", default = "auto",
      choices = { { "AUTO", "auto" }, { "XBOX", "xbox" }, { "PLAYSTATION", "playstation" }, { "NINTENDO", "nintendo" } },
      description = "How gamepad buttons are named on the controls screen. AUTO goes by the connected gamepad." },
    { key = "confirm_teleport", label = "ASK BEFORE TELEPORT", type = "toggle", default = true,
      description = "The Teleport shortcut asks before taking you back to the last Pokemon Center." },
  })
  local function option(key)
    local ok, value = pcall(function() return mod.options:get(key) end)
    if ok then return value end
    return nil
  end
  local I18n = load_("i18n.lua", mod, function() return option("language") end)
  local T, F = I18n.T, I18n.F
  local Field = load_("field.lua", mod)
  Field.confirmTeleport = function() return option("confirm_teleport") ~= false end

  local game
  local function try(fn, ...)
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
  end

  ---------------------------------------------------------------------------
  -- Actions
  ---------------------------------------------------------------------------
  local actions, order = {}, {}
  local function add(def)
    if not actions[def.id] then order[#order + 1] = def.id end
    actions[def.id] = def
  end
  for _, btn in ipairs({ "up", "down", "left", "right", "a", "b", "start", "select", "l", "r" }) do
    add({ id = btn, group = "buttons", kind = "hold", btn = btn })
  end
  local function hotkey(key)
    return function(g) if type(g._hotkey) == "function" then g:_hotkey(key) end end
  end
  local function speed(dir)
    return function(g) if type(g._cycleSpeed) == "function" then g:_cycleSpeed(dir) end end
  end
  add({ id = "speed_up", group = "game", kind = "tap", run = speed(1) })
  add({ id = "speed_down", group = "game", kind = "tap", run = speed(-1) })
  add({ id = "quick_save", group = "game", kind = "tap", run = hotkey("f1") })
  add({ id = "quick_load", group = "game", kind = "tap", run = hotkey("f2") })
  add({ id = "zoom_in", group = "game", kind = "tap", run = hotkey("=") })
  add({ id = "zoom_out", group = "game", kind = "tap", run = hotkey("-") })
  add({ id = "zoom_cycle", group = "game", kind = "tap", run = hotkey("4") })
  add({ id = "tilt", group = "game", kind = "tap", run = hotkey("3") })
  for _, id in ipairs(Field.ACTIONS) do
    add({ id = id, group = "field", kind = "field", run = function() Field.request(id) end })
  end
  local UI
  add({ id = "controls_menu", group = "mods", kind = "tap", run = function() UI.toggle() end })

  -- Slots 1-2: keyboard and mouse. Slots 3-4: gamepad.
  local DEFAULTS = {
    up = { "key:up", "key:w", "pad:dpup", "pad:ls_up" }, down = { "key:down", "key:s", "pad:dpdown", "pad:ls_down" },
    left = { "key:left", "key:a", "pad:dpleft", "pad:ls_left" }, right = { "key:right", "key:d", "pad:dpright", "pad:ls_right" },
    a = { "key:z", "key:return", "pad:a" }, b = { "key:x", "key:backspace", "pad:b" },
    start = { "key:escape", "key:kpenter", "pad:start" }, select = { "key:tab", "key:rshift", "pad:back" },
    l = { "key:q", "key:lctrl", "pad:leftshoulder" }, r = { "key:e", "key:rctrl", "pad:rightshoulder" },
    speed_up = { "key:1", nil, "pad:triggerright" }, speed_down = { "key:0", nil, "pad:triggerleft" },
    quick_save = { "key:f1" }, quick_load = { "key:f2" }, zoom_in = { "key:=" }, zoom_out = { "key:-" },
    zoom_cycle = { "key:4" }, tilt = { "key:3" }, controls_menu = { "key:f8" },
  }
  -- Keys the game answers by itself: with no action here they do nothing.
  local ENGINE_KEYS = {}
  for _, key in ipairs({ "up", "down", "left", "right", "w", "a", "s", "d", "z", "return", "space", "x", "backspace",
    "kpenter", "escape", "tab", "rshift", "lshift", "q", "e", "lctrl", "rctrl", "f1", "f2", "0", "1", "3", "4", "-", "=",
    "kp-", "kp+", "kp0", "kp1", "kp3", "kp4" }) do ENGINE_KEYS[key] = true end

  ---------------------------------------------------------------------------
  -- Bindings
  ---------------------------------------------------------------------------
  local SLOTS = 4
  local bindings = {}                  -- action id -> { [slot] = token }
  local index = { map = {}, menus = {} } -- place -> token -> the action that answers there
  local users = {}                     -- token -> list of action ids, in list order
  local function isField(id)
    local def = actions[id]
    return def ~= nil and (def.kind == "field" or def.context == "field")
  end
  -- Where an action can happen.
  local function onMap(id) return isField(id) or not (id == "l" or id == "r") end
  local function inMenus(id) return not isField(id) end
  local function clash(a, b)
    -- shortcuts for what is in front (a tree, a rock, water, a boulder) never apply together
    if isField(a) and isField(b) then return not (Field.FACING[a] and Field.FACING[b]) end
    return (onMap(a) and onMap(b)) or (inMenus(a) and inMenus(b))
  end
  local function reindex()
    index, users = { map = {}, menus = {} }, {}
    for _, id in ipairs(order) do
      local slots = bindings[id]
      for slot = 1, SLOTS do
        local token = slots and slots[slot]
        if token then
          users[token] = users[token] or {}
          users[token][#users[token] + 1] = id
          if not isField(id) then
            index.menus[token] = index.menus[token] or id
            index.map[token] = index.map[token] or id
          end
        end
      end
    end
    -- on the map a field shortcut answers before anything else; the built-in
    -- ones that share an input are tried one after the other
    index.shortcuts = {}
    for token, list in pairs(users) do
      for _, id in ipairs(list) do
        if isField(id) then
          if index.map[token] == nil or not isField(index.map[token]) then index.map[token] = id end
          if actions[id].kind == "field" and not actions[id].foreign then
            index.shortcuts[token] = index.shortcuts[token] or {}
            table.insert(index.shortcuts[token], id)
          end
        end
      end
    end
  end
  -- The actions that share this action's input in a slot and can happen in the same place.
  local function conflicts(id, slot)
    local token = bindings[id] and bindings[id][slot]
    local out = {}
    for _, other in ipairs(token and users[token] or {}) do
      if other ~= id and clash(id, other) then out[#out + 1] = other end
    end
    return out
  end
  local function conflictCount()
    local n = 0
    for token, list in pairs(users) do
      for i = 1, #list do
        for j = i + 1, #list do
          if clash(list[i], list[j]) then n = n + 1 end
        end
      end
    end
    return n
  end
  local function save()
    local lines = {}
    for id, slots in pairs(bindings) do
      for slot = 1, SLOTS do
        if slots[slot] then lines[#lines + 1] = id .. " " .. slot .. " " .. slots[slot] end
      end
    end
    table.sort(lines)
    if mod.cache and mod.cache.write then mod.cache:write("bindings/v1", "v1\n" .. table.concat(lines, "\n") .. "\n") end
  end
  local function defaults()
    bindings = {}
    for id, slots in pairs(DEFAULTS) do
      bindings[id] = {}
      for slot = 1, SLOTS do bindings[id][slot] = slots[slot] end
    end
    reindex()
  end
  local function loadBindings()
    local text = mod.cache and mod.cache.read and mod.cache:read("bindings/v1")
    if type(text) ~= "string" or not text:match("^v1") then return defaults() end
    bindings = {}
    for id, slot, token in text:gmatch("\n([%w_%.%-]+) (%d) ([^\n]+)") do
      slot = tonumber(slot)
      if slot >= 1 and slot <= SLOTS then
        bindings[id] = bindings[id] or {}
        bindings[id][slot] = token
      end
    end
    reindex()
  end
  loadBindings()

  local function deviceOf(token) return token:sub(1, 4) == "pad:" and "pad" or "kb" end
  local function clear(id, slot)
    if bindings[id] then bindings[id][slot] = nil end
    reindex(); save()
  end
  -- Puts an input in an action's slot. Nothing is taken from other actions:
  -- what now clashes with it is returned, for the screen to say.
  local function assign(id, slot, token)
    bindings[id] = bindings[id] or {}
    for s = 1, SLOTS do
      if s ~= slot and bindings[id][s] == token then bindings[id][s] = nil end
    end
    bindings[id][slot] = token
    reindex(); save()
    return conflicts(id, slot)
  end

  ---------------------------------------------------------------------------
  -- Doing what an input is bound to
  ---------------------------------------------------------------------------
  local active = {} -- token -> { btn, source } while it is held
  local function inputDown(token)
    if active[token] then return true end
    local id = Field.inOverworld() and index.map[token] or index.menus[token]
    local def = id and actions[id]
    if not def then return false end
    if def.kind == "hold" then
      local input = game and game.input
      local source = "trainer_controls:" .. token
      if input and input.sourcePress then
        try(input.sourcePress, input, def.btn, source)
        active[token] = { btn = def.btn, source = source }
      end
    elseif def.kind == "field" and not def.foreign and index.shortcuts[token] then
      active[token] = {}
      Field.request(index.shortcuts[token])
    else
      active[token] = {}
      local ok, err = pcall(def.run, game)
      if not ok and mod.log then mod.log:warn("action %s failed: %s", tostring(id), tostring(err)) end
    end
    return true
  end
  local function inputUp(token)
    local held = active[token]
    if not held then return false end
    active[token] = nil
    local input = game and game.input
    if held.btn and input and input.sourceRelease then try(input.sourceRelease, input, held.btn, held.source) end
    return true
  end
  local function releaseAll()
    for token in pairs(active) do inputUp(token) end
  end
  local function known(token) return users[token] ~= nil end

  ---------------------------------------------------------------------------
  -- Names of inputs
  ---------------------------------------------------------------------------
  local function family()
    local chosen = option("pad_labels")
    if chosen == "xbox" or chosen == "playstation" or chosen == "nintendo" then return chosen end
    local js = love.joystick
    for _, pad in ipairs(js and try(js.getJoysticks) or {}) do
      if try(pad.isGamepad, pad) then
        local name = tostring(try(pad.getName, pad) or ""):lower()
        if name:find("playstation") or name:find("dualsense") or name:find("dualshock") or name:find("ps%d") or name:find("sony") then return "playstation" end
        if name:find("nintendo") or name:find("switch") or name:find("joy%-con") or name:find("pro controller") then return "nintendo" end
        return "xbox"
      end
    end
    return "xbox"
  end
  local function label(token)
    if not token then return "" end
    local kind, name = token:match("^(%a+):(.+)$")
    if kind == "key" then
      local names = T("KEYS")
      return type(names) == "table" and names[name] or (#name == 1 and name:upper() or name:sub(1, 1):upper() .. name:sub(2))
    elseif kind == "mouse" then
      local names = T("MOUSE")
      return type(names) == "table" and names[tonumber(name)] or F("MOUSE_N", tonumber(name) or 0)
    elseif kind == "wheel" then
      return T(name == "up" and "WHEEL_UP" or "WHEEL_DOWN")
    elseif kind == "pad" then
      local raw = name:match("^raw(%d+)$")
      if raw then return F("PAD_EXTRA", tonumber(raw)) end
      local names = T("PAD_" .. family():upper())
      local common = T("PAD_COMMON")
      return (type(names) == "table" and names[name]) or (type(common) == "table" and common[name]) or name
    end
    return token
  end
  local function actionLabel(id)
    local def = actions[id]
    if def and def.label then
      local text = type(def.label) == "function" and try(def.label) or def.label
      if type(text) == "string" then return text end
    end
    local names = T("ACTIONS")
    return type(names) == "table" and names[id] or id
  end

  ---------------------------------------------------------------------------
  -- The screen and the panel
  ---------------------------------------------------------------------------
  UI = load_("ui.lua", {
    T = T, F = F, font = I18n.font, label = label, actionLabel = actionLabel,
    rows = function()
      local rows, last = {}, nil
      for _, group in ipairs({ "buttons", "game", "field", "mods" }) do
        for _, id in ipairs(order) do
          local def = actions[id]
          if def and (def.group or "mods") == group then
            if last ~= group then rows[#rows + 1] = { header = group }; last = group end
            rows[#rows + 1] = { id = id, field = isField(id) }
          end
        end
      end
      return rows
    end,
    binding = function(id, slot) return bindings[id] and bindings[id][slot] or nil end,
    assign = assign, clear = clear, deviceOf = deviceOf, conflicts = conflicts, conflictCount = conflictCount,
    reset = function() defaults(); save() end,
    -- the mod this one replaces answers the gamepad too, whatever is set here
    rival = function() return mod.find ~= nil and mod.find("pad_shortcuts") ~= nil end,
    releaseAll = releaseAll,
  })

  -- What a raw event means to the open screen.
  local NAV_KEYS = { up = "up", down = "down", left = "left", right = "right", ["return"] = "select", kpenter = "select",
    space = "select", z = "select", escape = "back", backspace = "back", x = "back", delete = "clear", r = "reset", f8 = "close" }
  local NAV_PAD = { dpup = "up", dpdown = "down", dpleft = "left", dpright = "right", ls_up = "up", ls_down = "down",
    ls_left = "left", ls_right = "right", a = "select", b = "back", y = "clear", x = "reset", start = "close" }

  -- Returns true when the event is used up.
  local function press(token)
    if UI.capturing() then UI.captured(token); return true end
    if UI.isOpen() then
      local kind, name = token:match("^(%a+):(.+)$")
      local nav = (kind == "key" and NAV_KEYS[name]) or (kind == "pad" and NAV_PAD[name])
      -- the menu's own input closes it again, whatever it is
      if not nav and index.menus[token] == "controls_menu" then nav = "close" end
      if nav then UI.nav(nav) end
      return true
    end
    return inputDown(token)
  end
  local function lift(token)
    if UI.isOpen() or UI.capturing() then inputUp(token); return true end
    return inputUp(token)
  end
  -- The game's own capture (its CONTROLS menu) keeps its events.
  local function standDown(g)
    local input = g and g.input
    return not game or (type(input) == "table" and input.captureArmed == true)
  end

  mod.hooks:wrap("input.key", function(nextHook, g, ev, ...)
    if type(ev) ~= "table" or type(ev.key) ~= "string" or standDown(g) then return nextHook(g, ev, ...) end
    local token = "key:" .. ev.key
    local used
    if ev.phase == "pressed" then
      -- with no input left for the screen, F8 still opens it
      if ev.key == "f8" and not UI.isOpen() and not UI.capturing() and not known(token)
          and not (bindings.controls_menu and next(bindings.controls_menu)) then
        UI.toggle()
        return
      end
      used = press(token)
    else
      used = lift(token)
    end
    -- the game's own keys, and the ones added in its CONTROLS menu, do nothing by themselves
    local own = type(g.input) == "table" and type(g.input.keyBindings) == "table" and g.input.keyBindings[ev.key] ~= nil
    if used or own or ENGINE_KEYS[ev.key] then return end
    return nextHook(g, ev, ...)
  end, 1000)

  local TRIGGERS = { triggerleft = "triggerleft", lefttrigger = "triggerleft", triggerright = "triggerright", righttrigger = "triggerright" }
  local STICKS = { leftx = { "ls_left", "ls_right" }, lefty = { "ls_up", "ls_down" },
    rightx = { "rs_left", "rs_right" }, righty = { "rs_up", "rs_down" } }
  local axisDown = {}
  local function axisEdge(name, on)
    if on and not axisDown[name] then axisDown[name] = true; press("pad:" .. name)
    elseif not on and axisDown[name] then axisDown[name] = nil; lift("pad:" .. name) end
  end
  mod.hooks:wrap("input.gamepad", function(nextHook, g, ev, ...)
    if type(ev) ~= "table" or standDown(g) then return nextHook(g, ev, ...) end
    if ev.phase == "pressed" or ev.phase == "released" then
      local button = TRIGGERS[ev.button] or ev.button
      if type(button) ~= "string" then return nextHook(g, ev, ...) end
      if ev.phase == "pressed" then press("pad:" .. button) else lift("pad:" .. button) end
      return
    elseif ev.phase == "axis" then
      local value = tonumber(ev.value) or 0
      local trigger = TRIGGERS[ev.axis]
      if trigger then
        -- pressed past 0.4, let go under 0.2
        if value >= 0.4 then axisEdge(trigger, true) elseif value <= 0.2 then axisEdge(trigger, false) end
        return
      end
      local pair = STICKS[ev.axis]
      if pair then
        -- pushed past half way, back once under 0.3
        if value <= -0.5 then axisEdge(pair[1], true) elseif value > -0.3 then axisEdge(pair[1], false) end
        if value >= 0.5 then axisEdge(pair[2], true) elseif value < 0.3 then axisEdge(pair[2], false) end
        return
      end
    end
    return nextHook(g, ev, ...)
  end, 1000)

  -- Buttons LÖVE has no name for (the DualSense touchpad click, extra paddles)
  -- send no event: they are read from the gamepad every step, by number.
  local STANDARD = { "a", "b", "x", "y", "back", "guide", "start", "leftstick", "rightstick",
    "leftshoulder", "rightshoulder", "dpup", "dpdown", "dpleft", "dpright" }
  local extras, extraDown = setmetatable({}, { __mode = "k" }), {}
  local function extraButtons(pad)
    local list = extras[pad]
    if list then return list end
    list = {}
    pcall(function()
      if not (pad.isGamepad and pad:isGamepad()) then return end
      local mapped, found = {}, 0
      for _, name in ipairs(STANDARD) do
        local ok, kind, n = pcall(pad.getGamepadMapping, pad, name)
        if ok and kind == "button" and type(n) == "number" then mapped[n] = true; found = found + 1 end
      end
      -- without a trustworthy mapping there is no telling what is "extra"
      if found < 8 then return end
      for n = 1, pad:getButtonCount() do
        if not mapped[n] then list[#list + 1] = n end
      end
    end)
    extras[pad] = list
    return list
  end
  local function pollExtras()
    local js = love.joystick
    local down = {}
    for _, pad in ipairs(js and try(js.getJoysticks) or {}) do
      for _, n in ipairs(extraButtons(pad)) do
        if try(pad.isDown, pad, n) then down[n] = true end
      end
    end
    for n in pairs(down) do
      if not extraDown[n] then extraDown[n] = true; press("pad:raw" .. n) end
    end
    for n in pairs(extraDown) do
      if not down[n] then extraDown[n] = nil; lift("pad:raw" .. n) end
    end
  end

  mod.hooks:wrap("input.step", function(nextHook, g, ...)
    if game and not standDown(g) then
      pcall(pollExtras)
      pcall(Field.step)
      pcall(UI.tick)
    end
    return nextHook(g, ...)
  end, 1000)

  -- Behind Trainer Desk, whose panels take their own clicks first.
  local hudRect
  mod.hooks:wrap("input.pointer", function(nextHook, g, ev, ...)
    if type(ev) ~= "table" or ev.source ~= "mouse" or standDown(g) then return nextHook(g, ev, ...) end
    if UI.isOpen() then
      if ev.phase == "pressed" and hudRect then UI.click(ev.x - hudRect.x, ev.y - hudRect.y, tonumber(ev.button) or 1) end
      return true
    end
    local button = tonumber(ev.button)
    if not button or (ev.phase ~= "pressed" and ev.phase ~= "released") then return nextHook(g, ev, ...) end
    local token = "mouse:" .. button
    if ev.phase == "pressed" then
      if UI.capturing() then UI.captured(token); return true end
      if inputDown(token) then return true end
    elseif inputUp(token) then
      return true
    end
    return nextHook(g, ev, ...)
  end, 1500)
  mod.hooks:wrap("input.wheel", function(nextHook, g, dy, ...)
    if type(dy) ~= "number" or dy == 0 or standDown(g) then return nextHook(g, dy, ...) end
    local token = dy > 0 and "wheel:up" or "wheel:down"
    if UI.capturing() then UI.captured(token); return true end
    if UI.isOpen() then UI.scroll(dy > 0 and -1 or 1); return true end
    if inputDown(token) then inputUp(token); return true end
    return nextHook(g, dy, ...)
  end, 1500)

  -- The screen, over the game picture.
  mod.hooks:wrap("render.hud", function(nextHook, g, viewport)
    nextHook(g, viewport)
    if not (UI.isOpen() and type(viewport) == "table") then return end
    local x, y = tonumber(viewport.gameX) or 0, tonumber(viewport.gameY) or 0
    local w = tonumber(viewport.gameWidth) or tonumber(viewport.width) or 480
    local h = tonumber(viewport.gameHeight) or tonumber(viewport.height) or 320
    hudRect = { x = x, y = y }
    love.graphics.push("all")
    love.graphics.translate(x, y)
    local ok, err = pcall(UI.draw, w, h, true)
    love.graphics.pop()
    if not ok and mod.log then mod.log:warn("controls screen: %s", tostring(err)); UI.close() end
  end, 900)

  -- The panel in Trainer Desk.
  local docked
  local function dockApi()
    local other = mod.find and mod.find("trainer_desk")
    local api = other and other.exports and other.exports.dock
    if type(api) == "table" and api.api == 1 and api.active() then return api end
  end
  local function undock()
    if not docked then return end
    pcall(docked.api.unregister, "trainer_controls.controls")
    docked = nil
  end
  local function syncDock(api)
    local language = tostring(option("language"))
    if docked and docked.api == api and docked.language == language then return end
    undock()
    api.register({ id = "trainer_controls.controls", title = T("TITLE"), width = 480, height = 432, pixel = 1,
      responsive = true, interval = 0.1, side = "right",
      draw = function(_, w, h)
        if api.theme then UI.theme(api.theme().colors) end
        UI.draw(w, h, false)
      end,
      pointer = function(action, x, y, amount)
        if action == "down" then UI.click(x, y, 1)
        elseif action == "wheel" then UI.scroll((tonumber(amount) or 0) > 0 and -1 or 1) end
      end })
    docked = { api = api, language = language }
  end
  mod.hooks:wrap("core.update", function(nextHook, g, dt)
    pcall(function()
      local api = game and dockApi()
      if api then syncDock(api) else undock() end
    end)
    return nextHook(g, dt)
  end, 860)
  mod.hooks:wrap("core.quit_to_launcher", function(nextHook)
    releaseAll(); UI.close(); game = nil
    pcall(undock)
    return nextHook()
  end, 860)
  mod.events:on("game.ready", function(payload)
    releaseAll()
    game = payload and payload.game
  end)

  ---------------------------------------------------------------------------
  -- For other mods: actions of their own in the list.
  --   register{ id, label (text or function), run = function(game), context = "field" (optional) }
  ---------------------------------------------------------------------------
  mod.exports = mod.exports or {}
  mod.exports.controls = {
    api = 1,
    register = function(def)
      if type(def) ~= "table" or type(def.id) ~= "string" or type(def.run) ~= "function" then return false end
      if not def.id:match("^[%w_%.%-]+$") or (actions[def.id] and not actions[def.id].foreign) then return false end
      add({ id = def.id, group = "mods", kind = def.context == "field" and "field" or "tap", context = def.context,
        label = def.label, run = def.run, foreign = true })
      reindex()
      return true
    end,
    unregister = function(id)
      if not (actions[id] and actions[id].foreign) then return false end
      actions[id] = nil
      for i, other in ipairs(order) do if other == id then table.remove(order, i) break end end
      reindex()
      return true
    end,
    open = function() if not UI.isOpen() then UI.toggle() end end,
    isOpen = function() return UI.isOpen() end,
  }
  mod.exports.debug = { ui = UI, bindings = function() return bindings end, label = label, assign = assign, clear = clear,
    reload = loadBindings, active = function() return active end, conflicts = conflicts, conflictCount = conflictCount }
end
