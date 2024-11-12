if script.active_mods["gvv"] then require("__gvv__.gvv")() end
local mod_gui    = require("__core__.lualib.mod-gui")
local tables     = require("__flib__.table")
local on_tick_n  = require("__flib__.on-tick-n")
local migration  = require("__flib__.migration")
local constants  = require("__virtm__.scripts.constants")
local vtm_gui    = require("__virtm__.scripts.gui.main_gui")
local vtm_logic  = require("__virtm__.scripts.vtm_logic")
local gui_util   = require("__virtm__.scripts.gui.utils")
local migrations = require("__virtm__.migrations")
local groups     = require("__virtm__.scripts.gui.groups")

local function init_global_data()
  -- definitions see classdef.lua
  ---@type GlobalGuis
  storage.guis = {}
  ---@type GlobalHistoryData
  storage.history = {}
  ---@type GlobalTrainData
  storage.trains = {}
  ---@type GlobalStationData
  storage.stations = {}
  ---@type GlobalPlayerSettings
  storage.settings = {}
  ---@type GlobalGroups
  storage.groups = {}
  ---@type GroupSet
  storage.group_set = {}
  ---@type {[string]:string}
  storage.surfaces = {
    ["All"] = "All",
    ["nauvis"] = "Nauvis",
  }
  -- cache relevant mods
  storage.TCS_active = script.active_mods["TCS_Icons"]
  storage.cybersyn_active = script.active_mods["cybersyn"]
  storage.SE_active = script.active_mods["space-exploration"]
  --cache relevant settings
  vtm_logic.cache_generic_settings()
end

local function remove_mod_gui_button(player)
  local button_flow = mod_gui.get_button_flow(player) --[[@as LuaGuiElement]]
  if button_flow.vtm_button then
    button_flow.vtm_button.destroy()
  end
end

migration.handle_on_configuration_changed(migrations.by_version, migrations.generic)

local function on_tick(event)
  -- for _, task in pairs(on_tick_n.retrieve(event.tick) or {}) do
  --   -- if task == "init_vtm_gui" then
  --   -- elseif task == "update_trains_tab" then
  --   -- end
  -- end

  -- station data refresh
  if storage.station_k then
    storage.station_k = tables.for_n_of(
      storage.station_update_table,
      storage.station_k, 10,
      vtm_logic.update_station)
    if storage.station_k == nil then
      storage.station_update_table = nil
      game.print({ "vtm.station-refresh-end" })
    end
  end
  if storage.station_refresh == "init" then
    storage.station_refresh = nil
    vtm_logic.init_stations()
  elseif storage.station_refresh == "all" then
    storage.station_refresh = nil
    vtm_logic.schedule_station_refresh()
  end
  for player_index, record in pairs(storage.settings) do
    if record.gui_refresh == "auto" and
        event.tick % (60 + 3 * player_index) == 0 then
      script.raise_event(constants.refresh_event, {
        player_index = player_index,
      })
    end
  end
end

local function on_se_elevator()
  if
      script.active_mods["space-exploration"]
      and remote.interfaces["space-exploration"]["get_on_train_teleport_started_event"]
  then
    script.on_event(
    ---@diagnostic disable-next-line: param-type-mismatch
      remote.call("space-exploration", "get_on_train_teleport_finished_event"),
      --- @param event on_train_teleported
      function(event)
        -- migrate stuff and things
        vtm_logic.migrate_train_SE(event)
      end
    )
  end
end

script.on_load(function()
  on_se_elevator()
end)

script.on_event(defines.events.on_tick, function(event)
  on_tick(event)
end)

script.on_init(function()
  on_tick_n.init()
  init_global_data()
  vtm_logic.load_guess_patterns()
  for _, player in pairs(game.players) do
    migrations.init_player_data(player)
    vtm_gui.create_gui(player)
    local gui_id = gui_util.get_gui_id(player.index)
    groups.create_gui(gui_id)

    -- do the button thing
    migrations.add_mod_gui_button(player)
  end
  on_se_elevator()
  storage.station_refresh = "init"
end)

-- script.on_event(defines.events.on_gui_opened, function(event)
--   if DEBUG then
--     if event.entity then
--       game.print("gui opened" .. event.entity.type)
--     end
--   end
-- end)

-- script.on_event(defines.events.on_gui_closed, function(event)
--   if event.entity and event.entity.type == "train-stop" then
--     -- game.print("gui closed" .. event.entity.type, { 0.5, 0, 0, 0.5 })
--   end
-- end)

script.on_event("vtm-open", function(event)
  vtm_gui.open_or_close_gui(event.player_index)
end)

script.on_event("vtm-groups-open", function(event)
  groups.toggle_groups_gui(event.player_index)
end)

script.on_event(defines.events.on_lua_shortcut, function(event)
  if event.prototype_name == "vtm-open" then
    vtm_gui.open_or_close_gui(event.player_index)
  elseif event.prototype_name == "vtm-groups-open" then
    groups.toggle_groups_gui(event.player_index)
  end
end)

script.on_event("vtm-linked-focus-search", function(event)
  vtm_gui.handle_action({
    type = "generic",
    action = "focus_search",
    gui_id = gui_util.get_gui_id(event.player_index)
  }, event)
end)

script.on_event(defines.events.on_player_created, function(event)
  local player = game.players[event.player_index]
  migrations.init_player_data(player)
  migrations.add_mod_gui_button(player)
  vtm_gui.create_gui(player)
  local gui_id = gui_util.get_gui_id(player.index)
  groups.create_gui(gui_id)
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
    vtm_logic.load_guess_patterns()
    storage.station_refresh = "all"
  end
  if event["setting"] == "vtm-showModgui" then
    local player = game.players[event.player_index]
    if settings.get_player_settings(event.player_index)["vtm-showModgui"].value == false then
      remove_mod_gui_button(player)
    else
      migrations.add_mod_gui_button(player)
    end
  end
  --refresh cached settings
  vtm_logic.cache_generic_settings()
end)


-- COMMANDS
commands.add_command("vtm-show-undef-stations", { "vtm.command-help" }, function(event)
  local player = game.get_player(event.player_index)
  if player == nil then return end
  local force = player.valid and player.force or 1
  local table_index = 0
  force.print({ "vtm.show-undef-stations" })
  if script.active_mods["space-exploration"] then
    force.print({ "", { "vtm.filter-surface" }, ": ", storage.settings[event.player_index].surface })
  end

  for _, station_data in pairs(storage.stations) do
    if station_data.station.valid and
        station_data.force_index == player.force.index and
        station_data.type == "ND" and
        (
          script.active_mods["space-exploration"] and
          station_data.station.surface.name == storage.settings[event.player_index].surface
          or
          script.active_mods["space-exploration"] and
          storage.settings[event.player_index].surface == "All"
          or
          not script.active_mods["space-exploration"] and true
        )
    then
      table_index = table_index + 1
      force.print("[train-stop=" .. station_data.station.unit_number .. "]")
      if table_index == 10 then return end
    end
  end
end)

commands.add_command("vtm-count-history", { "vtm.command-help" }, function(event)
  local player = game.get_player(event.player_index)
  if player == nil then return end
  player.print("History Records: " .. table_size(storage.history))
end)

commands.add_command("vtm-del-all-groups", { "vtm.command-help" }, function(event)
  local player = game.get_player(event.player_index)
  if player == nil or not player.admin then return end
  storage.groups = {}
  storage.group_set = {}

  player.print(player.name .. " deleted all group data ")
end)
