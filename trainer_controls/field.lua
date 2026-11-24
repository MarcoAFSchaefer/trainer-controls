-- field.lua: field shortcuts, the things otherwise reached through the
-- Pokémon menu or the Bag. Each one goes down the game's own path, so it only
-- works when the menu would offer it: the badge, a party Pokémon that knows
-- the move, the item in the Bag, and a place where it applies.
return function(mod)
  local Field_ = {}
  local ITEM_BICYCLE, ITEM_ITEMFINDER, ITEM_VS_SEEKER = 360, 261, 362
  local MOVE_OF = { cut = "CUT", flash = "FLASH", surf = "SURF", strength = "STRENGTH", teleport = "TELEPORT",
    fly = "FLY", rock_smash = "ROCK_SMASH", waterfall = "WATERFALL", dig = "DIG", sweet_scent = "SWEET_SCENT" }
  local DELTA = { up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 } }
  Field_.ACTIONS = { "cut", "surf", "fly", "strength", "flash", "rock_smash", "waterfall", "dig", "teleport",
    "sweet_scent", "bike", "itemfinder", "vs_seeker" }
  Field_.confirmTeleport = function() return true end

  local function req(name)
    local ok, m = pcall(require, name)
    if ok and type(m) == "table" then return m end
    return nil
  end

  -- On the map, with no menu, message, battle or transition on screen.
  local function inOverworld()
    local Field = req("src.core.game3.field")
    if not (Field and Field.running) then return false end
    local Hud = req("src.ui.game3.hud")
    if Hud and Hud.busy and Hud.busy() then return false end
    return true, Field
  end
  Field_.inOverworld = function() return (inOverworld()) end

  -- "blocked": waiting will not help. "moving": the step only has to end.
  local function fieldState()
    local over, Field = inOverworld()
    if not over then return "blocked" end
    if Field.locked or (Field.isLocked and Field.isLocked()) then return "blocked" end
    if Field.callbackPending and Field.callbackPending() then return "blocked" end
    local Space = req("src.core.game3.scripting.space")
    if Space and Space.vm and Space.vm.isRunning and Space.vm:isRunning() then return "blocked" end
    local P = req("src.core.game3.player")
    if not P then return "blocked" end
    if P.boulderPush or P.fishing or P.fieldMoveAnim and P.fieldMoveAnim > 0 then return "blocked" end
    if P.moving or P.jumping then return "moving" end
    local session = Field._session
    if type(session) ~= "table" then return "blocked" end
    return "free", Field, P, session
  end

  local function headerFlag(mapDef, key)
    if mapDef == nil then return false end
    return (tonumber(mapDef[key]) or 0) ~= 0
  end

  -- The context the Pokémon menu builds before a field move is used.
  local function moveContext(Field, P, session, mon, FieldMoves)
    local Collision = req("src.core.game3.collision") or {}
    local Objects = req("src.core.game3.objects") or {}
    local Map = req("src.core.game3.map") or {}
    local Space = req("src.core.game3.scripting.space")
    local d = DELTA[P.facing or "down"] or DELTA.down
    local fx, fy = (P.cellX or 0) + d[1], (P.cellY or 0) + d[2]
    local grass = false
    if Collision.isGrass then
      for y = (P.cellY or 0) - 1, (P.cellY or 0) + 1 do
        for x = (P.cellX or 0) - 1, (P.cellX or 0) + 1 do
          local e = Collision.elevationAt and Collision.elevationAt(x, y)
          if (P.elevation == nil or e == P.elevation) and Collision.isGrass(x, y) then grass = true end
        end
      end
    end
    local mapDef = Map.currentDef and Map.currentDef()
    local behavior = Collision.behavior and Collision.behavior(fx, fy)
    return {
      party = session.party, mon = mon, store = Space and Space.store, session = session, game = Field._game,
      facingObject = Objects.at and Objects.at(fx, fy),
      isFacingWater = Collision.isWater and Collision.isWater(fx, fy) or false,
      isFacingWaterfall = FieldMoves.isWaterfallBehavior and FieldMoves.isWaterfallBehavior(behavior) or false,
      facing = P.facing, isSurfing = P.surfing == true, hasCuttableGrass = grass,
      mapType = mapDef and mapDef.mapType, isCave = headerFlag(mapDef, "cave"),
      canEscapeRope = headerFlag(mapDef, "allowEscaping"), escapeWarp = session.escapeWarp,
    }
  end

  local function teleportQuestion(Field, session)
    local text
    pcall(function()
      local RomText = require("src.core.game3.rom_text")
      local Sections = require("src.import.gba.map_sections_extract")
      local game = Field._game
      local dest = session.healMap
      local def = game and game.data and game.data.maps and game.data.maps[dest]
      local place = Sections.getPlaceName(dest, def and def.regionMapSectionId)
      text = RomText.box("gText_ReturnToHealingSpot", { stringVars = { place }, maxWidth = 216 })
    end)
    return text
  end

  local function useMove(action, Field, P, session)
    local FieldMoves = req("src.core.game3.field_moves")
    if not (FieldMoves and FieldMoves.fromMenu and Field.executeFieldMove) then return false end
    local name = MOVE_OF[action]
    local party = session.party
    if type(party) ~= "table" then return false end
    local mon = FieldMoves.partyMoveUser(party, name, { game = Field._game })
    if not mon then return false end
    local res = FieldMoves.fromMenu(name, moveContext(Field, P, session, mon, FieldMoves))
    if type(res) ~= "table" or not res.ok then return false end
    if res.action == "fly" then
      -- opened straight from the map: cancelling the fly map goes back to the field
      local PartyMenu = req("src.ui.game3.party_menu")
      if PartyMenu then PartyMenu._flyReturn = nil end
    end
    if (res.action == "teleport" or res.action == "dig") and Field_.confirmTeleport() then
      local Message = req("src.ui.game3.message")
      local Choice = req("src.ui.game3.choice")
      local text = res.action == "teleport" and teleportQuestion(Field, session) or nil
      if Message and Choice and Message.show and Choice.yesNo and text then
        Message.show(text, function()
          Choice.yesNo(function(yes)
            Message.close()
            if yes then Field.executeFieldMove(res) end
          end)
        end)
        return true
      end
    end
    Field.executeFieldMove(res)
    return true
  end

  local function hasItem(session, id)
    local Bag = req("src.core.game3.bag")
    if not (Bag and Bag.has and session.bag) then return false end
    local ok, has = pcall(Bag.has, session.bag, id, 1)
    return ok and has == true
  end

  local function useItem(action, Field, P, session)
    if action == "bike" then
      if not hasItem(session, ITEM_BICYCLE) then return false end
      local ItemUse = req("src.core.game3.item_use")
      if not (ItemUse and ItemUse.useField) then return false end
      return ItemUse.useField(session, session.bag, ITEM_BICYCLE) == true
    elseif action == "itemfinder" then
      if not hasItem(session, ITEM_ITEMFINDER) then return false end
      if not Field.useItemfinder then return false end
      Field.useItemfinder(session, true)
      return true
    elseif action == "vs_seeker" then
      if not hasItem(session, ITEM_VS_SEEKER) then return false end
      local ItemUse = req("src.core.game3.item_use")
      local VsSeeker = req("src.core.game3.vs_seeker")
      if not (ItemUse and ItemUse.useField and VsSeeker and VsSeeker.use) then return false end
      local ok, kind = ItemUse.useField(session, session.bag, ITEM_VS_SEEKER)
      if ok ~= true or kind ~= "vs_seeker" then return false end
      VsSeeker.use(session, nil)
      return true
    end
    return false
  end

  local function perform(action)
    local state, Field, P, session = fieldState()
    if state ~= "free" then return state end
    local ok, done
    if MOVE_OF[action] then ok, done = pcall(useMove, action, Field, P, session)
    else ok, done = pcall(useItem, action, Field, P, session) end
    if not ok and mod.log then mod.log:warn("shortcut %s failed: %s", action, tostring(done)) end
    return "done", ok and done == true
  end

  -- Shortcuts that act on what is right in front of the player. No two of
  -- them can apply at once, so they may share one input: the one that fits is used.
  Field_.FACING = { cut = true, rock_smash = true, surf = true, waterfall = true, strength = true }
  -- Several shortcuts on one input: each is tried until one can be used. Cut
  -- goes last among them, since it also works on tall grass with nothing in front.
  local function tryAll(list)
    local last
    for pass = 1, 2 do
      for _, action in ipairs(list) do
        if (action == "cut") == (pass == 2) then
          local state, used = perform(action)
          last = state
          if state ~= "done" or used then return state end
        end
      end
    end
    return last or "done"
  end
  -- A press in the middle of a step waits for the step to end.
  local pending
  function Field_.request(actions)
    if type(actions) ~= "table" then actions = { actions } end
    if tryAll(actions) == "moving" then pending = { actions = actions, steps = 20 } else pending = nil end
  end
  function Field_.step()
    if not pending then return end
    pending.steps = pending.steps - 1
    local state = tryAll(pending.actions)
    if state ~= "moving" or pending.steps <= 0 then pending = nil end
  end
  return Field_
end
