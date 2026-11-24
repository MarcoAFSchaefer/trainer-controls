-- ui.lua: the list of actions and their inputs, drawn two ways: as a screen
-- over the game picture and as a Trainer Desk panel. One row per action, four
-- cells per row (two for keyboard and mouse, two for the gamepad). Choosing a
-- cell waits for the next input and puts it there.
--
-- While it waits, every key and button is an answer, so nothing on the
-- keyboard or gamepad can cancel: the wait ends by itself after a few seconds,
-- or with the Cancel button.
return function(env)
  local G = love.graphics
  local T, F = env.T, env.F
  local floor, max, min = math.floor, math.max, math.min
  local UI = {}
  local WAIT = 6 -- seconds an input is waited for

  local function hex(v) return { tonumber(v:sub(1, 2), 16) / 255, tonumber(v:sub(3, 4), 16) / 255, tonumber(v:sub(5, 6), 16) / 255 } end
  local C = { bg = hex("0f1216"), card = hex("1b1f26"), line = hex("2f3742"), text = hex("e6ebf2"), muted = hex("9aa5b4"),
    accent = hex("4f9cf7"), warn = hex("d1912a"), bad = hex("e0625a"), off = hex("252b34") }
  function UI.theme(colors)
    if type(colors) ~= "table" then return end
    C.bg, C.card, C.off = colors.panel or C.bg, colors.dock or C.card, colors.tabActive or C.off
    C.text, C.muted, C.accent = colors.textActive or C.text, colors.text or C.muted, colors.accent or C.accent
  end

  local state = { open = false, row = nil, col = 1, scroll = 0, capture = nil, message = nil, resetArmed = false }
  local hits, visible, rowsNow = {}, 8, {}
  UI.state = state

  local function now() return love.timer.getTime() end
  local function rows()
    rowsNow = env.rows()
    return rowsNow
  end
  local function firstAction(list)
    for i, row in ipairs(list) do if row.id then return i end end
  end
  local function selected()
    local list = rowsNow
    if not (state.row and list[state.row] and list[state.row].id) then state.row = firstAction(list) end
    return state.row and list[state.row] or nil
  end
  local function keepInView()
    if not state.row then return end
    -- a section's first action brings its heading along
    local top = state.row
    if rowsNow[top - 1] and rowsNow[top - 1].header then top = top - 1 end
    if top <= state.scroll then state.scroll = top - 1 end
    if state.row > state.scroll + visible then state.scroll = state.row - visible end
    state.scroll = max(0, min(max(0, #rowsNow - visible), state.scroll))
  end

  function UI.isOpen() return state.open end
  function UI.capturing() return state.capture ~= nil end
  function UI.close()
    state.open, state.capture, state.resetArmed = false, nil, false
  end
  function UI.toggle()
    if state.open then return UI.close() end
    env.releaseAll()
    rows()
    state.open, state.message, state.resetArmed = true, nil, false
    selected(); keepInView()
  end
  local function startCapture()
    local row = selected()
    if not row then return end
    env.releaseAll()
    state.capture = { id = row.id, slot = state.col, device = state.col <= 2 and "kb" or "pad", deadline = now() + WAIT }
    state.resetArmed = false
  end
  -- An input arrived while waiting: it goes in the cell when it is of the
  -- cell's kind (a gamepad button is no answer for a keyboard cell).
  function UI.captured(token)
    local cap = state.capture
    if not cap then return end
    if env.deviceOf(token) ~= cap.device then return end
    local clashes = env.assign(cap.id, cap.slot, token)
    state.capture = nil
    if clashes[1] then state.message, state.messageBad = F("CONFLICT", env.label(token), env.actionLabel(clashes[1])), true
    else state.message, state.messageBad = F("BOUND", env.label(token), env.actionLabel(cap.id)), false end
  end
  function UI.tick()
    if state.capture and now() > state.capture.deadline then
      state.capture, state.message = nil, T("TIMED_OUT")
    end
  end
  local function clearSelected()
    local row = selected()
    if not row then return end
    env.clear(row.id, state.col)
    state.capture, state.messageBad = nil, false
    state.message = F("CLEARED", env.actionLabel(row.id))
  end
  local function resetAll()
    if not state.resetArmed then
      state.resetArmed, state.message = true, T("RESET_CONFIRM")
      return
    end
    env.reset()
    state.resetArmed, state.message = false, T("RESET_DONE")
  end

  function UI.nav(what)
    if state.capture then return end
    local list = rows()
    selected()
    if what ~= "back" and what ~= "reset" then state.resetArmed = false end
    if what == "up" or what == "down" then
      local step, at = what == "up" and -1 or 1, state.row or 0
      repeat at = at + step until not list[at] or list[at].id
      if list[at] then state.row = at end
      state.message = nil
      keepInView()
    elseif what == "left" then state.col = max(1, state.col - 1)
    elseif what == "right" then state.col = min(4, state.col + 1)
    elseif what == "select" then startCapture()
    elseif what == "clear" then clearSelected()
    elseif what == "reset" then resetAll()
    elseif what == "back" then
      if state.resetArmed then state.resetArmed, state.message = false, nil else UI.close() end
    elseif what == "close" then UI.close()
    end
  end
  function UI.scroll(by)
    if state.capture then
      if state.capture.device == "kb" then UI.captured(by < 0 and "wheel:up" or "wheel:down") end
      return
    end
    state.scroll = max(0, min(max(0, #rowsNow - visible), state.scroll + by))
  end
  function UI.click(x, y, button)
    -- another mouse button while a keyboard/mouse cell waits is an answer
    if state.capture and state.capture.device == "kb" and (tonumber(button) or 1) ~= 1 then
      return UI.captured("mouse:" .. button)
    end
    for i = #hits, 1, -1 do
      local at = hits[i]
      if x >= at.x and x < at.x + at.w and y >= at.y and y < at.y + at.h then
        if state.capture and not at.whileWaiting then return end
        at.run()
        return
      end
    end
  end

  ---------------------------------------------------------------------------
  -- Drawing
  ---------------------------------------------------------------------------
  local fonts = {}
  local function font(size)
    size = max(8, floor(size + 0.5))
    if not fonts[size] then fonts[size] = env.font(size) end
    return fonts[size]
  end
  local s = 1
  local function color(c, a) G.setColor(c[1], c[2], c[3], a or 1) end
  local function box(x, y, w, h, c, r, a)
    color(c, a)
    G.rectangle("fill", floor(x * s), floor(y * s), floor(w * s + 0.5), floor(h * s + 0.5), (r or 4) * s, (r or 4) * s)
  end
  local function shorten(f, str, room)
    str = tostring(str)
    if f:getWidth(str) <= room then return str end
    local list = {}
    for ch in str:gmatch("[%z\1-\127\194-\244][\128-\191]*") do list[#list + 1] = ch end
    while #list > 0 and f:getWidth(table.concat(list) .. "..") > room do list[#list] = nil end
    return table.concat(list) .. ".."
  end
  local function text(str, x, y, c, size, room, align)
    local f = font(size * s)
    G.setFont(f)
    color(c)
    room = max(1, room * s)
    str = shorten(f, str, room)
    local px = x * s
    if align == "center" then px = px + (room - f:getWidth(str)) / 2
    elseif align == "right" then px = px + room - f:getWidth(str) end
    G.print(str, floor(px), floor(y * s))
  end
  local function middle(str, x, y, w, h, c, size)
    local f = font(size * s)
    text(str, x + 2, y + (h - f:getHeight() / s) / 2, c, size, w - 4, "center")
  end
  local function hit(x, y, w, h, run, whileWaiting)
    hits[#hits + 1] = { x = x * s, y = y * s, w = w * s, h = h * s, run = run, whileWaiting = whileWaiting }
  end
  local function button(label, x, y, w, h, run, fill, whileWaiting)
    box(x, y, w, h, fill or C.off, 5)
    middle(label, x, y, w, h, C.text, 11)
    hit(x, y, w, h, run, whileWaiting)
  end

  -- overlay: over the game (dimmed behind, with a Close button).
  function UI.draw(w, h, overlay)
    hits = {}
    UI.tick()
    local list = rows()
    selected()
    s = max(0.6, min(3, min(w / 480, h / 300)))
    local W, H = w / s, h / s
    G.push("all")
    color(C.bg, overlay and 0.94 or 1)
    G.rectangle("fill", 0, 0, w, h)
    text(T("TITLE"), 10, 6, C.text, 14, 200)
    if not overlay then text(T("HINT_PANEL"), 150, 9, C.muted, 9, W - 160, "right") end

    local slotW, gap = 76, 4
    local slotX = W - 10 - 4 * slotW - 3 * gap
    text(T("COL_KEYBOARD"), slotX, 27, C.muted, 9, slotW * 2 + gap, "center")
    text(T("COL_GAMEPAD"), slotX + 2 * (slotW + gap), 27, C.muted, 9, slotW * 2 + gap, "center")

    local top, rowH = 42, 20
    visible = max(3, floor((H - 54 - top) / rowH))
    state.scroll = max(0, min(max(0, #list - visible), state.scroll))
    local cap = state.capture
    for slot = 1, visible do
      local at = state.scroll + slot
      local row = list[at]
      if not row then break end
      local y = top + (slot - 1) * rowH
      if row.header then
        local names = T("GROUPS")
        text(type(names) == "table" and names[row.header] or row.header, 10, y + 5, C.accent, 9, slotX - 14)
        color(C.line); G.rectangle("fill", floor(slotX * s), floor((y + 11) * s), floor((W - 10 - slotX) * s), 1)
      else
        text(env.actionLabel(row.id), 14, y + 3, C.text, 11, slotX - 18)
        for col = 1, 4 do
          local x = slotX + (col - 1) * (slotW + gap)
          local waiting = cap and cap.id == row.id and cap.slot == col
          local chosen = at == state.row and col == state.col
          box(x, y + 1, slotW, rowH - 2, waiting and C.warn or (chosen and C.off or C.card), 4)
          if chosen and not waiting then
            color(C.accent); G.setLineWidth(max(1, s))
            G.rectangle("line", floor(x * s) + 0.5, floor((y + 1) * s) + 0.5, floor(slotW * s), floor((rowH - 2) * s), 4 * s, 4 * s)
          end
          local token = env.binding(row.id, col)
          local clashing = token and not waiting and env.conflicts(row.id, col)[1] ~= nil
          if clashing then
            -- the same input also does something else here
            color(C.bad); G.setLineWidth(max(1, s))
            G.rectangle("line", floor(x * s) + 0.5, floor((y + 1) * s) + 0.5, floor(slotW * s), floor((rowH - 2) * s), 4 * s, 4 * s)
          end
          middle(waiting and "..." or (token and ((clashing and "! " or "") .. env.label(token)) or "-"), x, y + 1, slotW, rowH - 2,
            clashing and C.bad or ((token or waiting) and C.text or C.line), 10)
          hit(x, y + 1, slotW, rowH - 2, function()
            state.row, state.col, state.message = at, col, nil
            startCapture()
          end, true)
        end
      end
    end
    -- how far down the list is
    if #list > visible then
      local trackH = visible * rowH
      box(W - 6, top, 3, trackH, C.card, 1)
      box(W - 6, top + trackH * state.scroll / #list, 3, trackH * visible / #list, C.line, 1)
    end

    -- message and buttons
    local my, by = H - 48, H - 28
    local row = selected()
    local total = env.conflictCount()
    if total > 0 then text(F("CONFLICTS", total), 100, 9, C.bad, 9, 120) end
    if cap then
      local left = max(0, math.ceil(cap.deadline - now()))
      text(F(cap.device == "kb" and "WAIT_KEYBOARD" or "WAIT_GAMEPAD", env.actionLabel(cap.id), left), 10, my, C.warn, 11, W - 20)
      -- remove what is there, or leave it as it is, without pressing anything
      local list = { { T("REMOVE"), clearSelected }, { T("CANCEL"), function() state.capture, state.message = nil, nil end } }
      if cap.device == "kb" then table.insert(list, 1, { T("LEFT_CLICK"), function() UI.captured("mouse:1") end }) end
      local bw = (W - 20 - gap * (#list - 1)) / #list
      for i, def in ipairs(list) do
        button(def[1], 10 + (i - 1) * (bw + gap), by, bw, 22, def[2], C.off, true)
      end
    else
      -- the chosen cell's conflict comes before any other note
      local clashes = row and env.conflicts(row.id, state.col) or {}
      local token = row and env.binding(row.id, state.col)
      local bad = clashes[1] ~= nil and not (state.message and not state.messageBad)
      local rival = env.rival()
      if rival then bad = true end
      local note = (rival and T("OLD_MOD")) or (bad and F("CONFLICT", env.label(token), env.actionLabel(clashes[1])))
        or state.message or (row and row.field and T("FIELD_HINT")) or T(overlay and "HINT_SCREEN" or "HINT_CELL")
      text(note, 10, my, bad and C.bad or (state.message and C.accent or C.muted), 10, W - 20)
      local labels = { { T("CHANGE"), startCapture }, { T("CLEAR"), clearSelected },
        { T(state.resetArmed and "RESET_AGAIN" or "RESET"), resetAll, state.resetArmed and C.warn or nil } }
      if overlay then labels[#labels + 1] = { T("CLOSE"), UI.close } end
      local bw = (W - 20 - gap * (#labels - 1)) / #labels
      for i, def in ipairs(labels) do
        button(def[1], 10 + (i - 1) * (bw + gap), by, bw, 22, def[2], def[3])
      end
    end
    G.pop()
  end
  return UI
end
