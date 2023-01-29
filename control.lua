local tables = require("__flib__.table")
local on_tick_n = require("__flib__.on-tick-n")
local constants = require("__vtm__.scripts.constants")
local vtm_gui = require("__vtm__.scripts.gui.main_gui")
local vtm_logic = require("__vtm__.scripts.vtm_logic")
local gui_util = require("__vtm__.scripts.gui.utils")
local mod_gui = require("__core__.lualib.mod-gui")

local function init_player_data(player)
  if player.valid then
    -- init personal settings
    global.settings[player.index] = {
      current_tab = "trains",
      state = "closed",
      pinned = false,
      gui_refresh = ""
    }
    -- init stats per force
    if global.stats[player.force] == nil then
      global.stats[player.force] = {
        stations = {},
        trains = {},
      }
    end
  end
end

local function init_global_data()
  global.guis = {}
  global.history = {}
  global.trains = {}
  global.stations = {}
  global.settings = {}
  global.stats = {}
end

local function remove_mod_gui_button(player)
  local button_flow = mod_gui.get_button_flow(player) --[[@as LuaGuiElement]]
  if button_flow.vtm_button then
    button_flow.vtm_button.destroy()
  end

end

local function add_mod_gui_button(player)
  local button_flow = mod_gui.get_button_flow(player) --[[@as LuaGuiElement]]
  if not settings.player["vtm-showModgui"] then
    return
  end
  if button_flow.vtm_button then
    return
  end
  button_flow.add {
    type = "button",
    name = "vtm_button",
    style = mod_gui.button_style,
    caption = "VTM",
    tags = {
      [script.mod_name] = {
        flib = {
          on_click = { type = "generic", action = "open-vtm" }
        }
      }
    },
    tooltip = { "vtm.mod-gui-tooltip" }
  }
end

local function on_configuration_changed(event)
  for _, player in pairs(game.players) do
    if player.valid then
      if global.trains[1] ~= nil and global.trains[1].prototype == nil then
        global.trains = {} -- FIXME: remove before release
      end
      -- init personal settings
      if global.settings[player.index] == nil then
        init_player_data(player)
        -- init stats per force
        if global.stats[player.force] == nil then
          global.stats[player.force] = {
            stations = {},
            trains = {},
          }
        end
      end
      local gui_id = gui_util.get_gui_id(player.index)
      if gui_id ~= nil then
        vtm_gui.destroy(player.index)
      end
      vtm_gui.create_gui(player)
      script.raise_event(constants.refresh_event, {
        player_index = player.index,
      })
      add_mod_gui_button(player)
    end
  end
  if global.station_refresh == "init" then
    return
  end
  vtm_logic.update_all_stations("force")
end

local function on_tick(event)
  -- for _, task in pairs(on_tick_n.retrieve(event.tick) or {}) do
  --   -- if task == "init_vtm_gui" then
  --   -- elseif task == "update_trains_tab" then
  --   -- end
  -- end

  -- station data refresh
  if global.station_k then
    global.station_k = tables.for_n_of(
      global.station_update_table,
      global.station_k, 10,
      vtm_logic.update_station)
  end
  if global.station_refresh == "init" then
    global.station_refresh = nil
    vtm_logic.init_stations()
  elseif global.station_refresh == "all" then
    global.station_refresh = nil
    vtm_logic.schedule_station_refresh()
  end
  for _, player in pairs(game.players) do
    if global.settings[player.index].gui_refresh == "auto" and
        event.tick % (60 + 3 * player.index) == 0 then
      script.raise_event(constants.refresh_event, {
        player_index = player.index,
      })
    end
  end

end

-- local function on_load()
-- end

script.on_event(defines.events.on_tick, function(event)
  on_tick(event)
end)

-- script.on_load(function()
--   on_load()
-- end)

script.on_init(function()
  on_tick_n.init()
  init_global_data()
  for _, player in pairs(game.players) do
    init_player_data(player)
  end
  global.station_refresh = "init"
end)

-- script.on_event(defines.events.on_gui_opened, function(event)
--   if event.entity and event.entity.type == "train-stop" then
--     -- game.print("gui opened" .. event.entity.type)
--   end
-- end)
-- script.on_event(defines.events.on_gui_closed, function(event)

--   if event.element and event.element.name == "vtm_main_frame" then

--   end
--   if event.entity and event.entity.type == "train-stop" then
--     -- game.print("gui closed" .. event.entity.type, { 0.5, 0, 0, 0.5 })
--   end
-- end)

script.on_event("vtm-open", function(event)
  vtm_gui.open_or_close_gui(game.players[event.player_index])
end)

script.on_configuration_changed(function(event)
  on_configuration_changed(event)
end)

script.on_event(defines.events.on_player_joined_game, function(event)
  -- local player = game.players[event.player_index]
  -- init_player_data(player)
  -- add_mod_gui_button(player)
  -- vtm_gui.create_gui(player)
end)

script.on_event(defines.events.on_player_created, function(event)
  local player = game.players[event.player_index]
  init_player_data(player)
  add_mod_gui_button(player)
  vtm_gui.create_gui(player)
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  if tables.find({
    "vtm-requester-names",
    "vtm-provider-names",
    "vtm-depot-names",
    "vtm-refuel-names",
    "vtm-p-or-r-start"
  }, event["setting"])
  then
    vtm_logic.load_guess_pattern()
    global.station_refresh = "all"
  end
  if event["setting"] == "vtm-showModgui" then
    local player = game.players[event.player_index]
    if settings.get_player_settings(event.player_index)["vtm-showModgui"].value == false then
      remove_mod_gui_button(player)
    else
      add_mod_gui_button(player)
    end
  end
end)


-- COMMANDS
-- TODO: clean or remove
commands.add_command("vtm", { "vtm.command-help" }, function(event)
  if event.parameter == "show-undef-stations" then
    local player = game.get_player(event.player_index)
    if player == nil then return end
    local force = player.valid and player.force or 1
    local table_index = 0
    force.print({ "vtm.show-undef-stations" })
    for _, station_data in pairs(global.stations) do
      if station_data.station.valid and
          station_data.force_index == player.force.index and
          station_data.type == "ND"
      then
        table_index = table_index + 1
        force.print("[train-stop=" .. station_data.station.unit_number .. "]")
        if table_index == 10 then return end
      end
    end
  elseif event.parameter == "count-history" then
    local player = game.get_player(event.player_index)
    if player == nil then return end
    player.print("History Records: " .. table_size(global.history))
  elseif event.parameter == "del-history" then
    global.history = {}
  elseif event.parameter == "del-stations" then
    global.stations = {}
    game.print("Station data deleted by " .. game.players[event.player_index].name)
  elseif event.parameter == "del-settings" then
    global.settings = {}
  elseif event.parameter == "refresh-stations" then
    global.station_refresh = "all"
  end
end)
