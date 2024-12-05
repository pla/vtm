if script.active_mods["gvv"] then require("__gvv__.gvv")() end
local tables         = require("__flib__.table")
local flib_migration = require("__flib__.migration")
local constants      = require("__virtm__.scripts.constants")
local main_gui       = require("__virtm__.scripts.gui.main_gui")
local backend        = require("__virtm__.scripts.backend")
local gui_utils      = require("__virtm__.scripts.gui.utils")
local migrations     = require("__virtm__.migrations")
local groups         = require("__virtm__.scripts.gui.groups")

local handler        = require("__core__.lualib.event_handler")

local control        = {}

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
  ---@type {[string]:string|table}
  storage.surfaces = {
    ["All"] = "All",
  }

  --cache relevant settings
  gui_utils.cache_generic_settings()
end

flib_migration.handle_on_configuration_changed(migrations.by_version, migrations.generic)

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
      backend.update_station)
    if storage.station_k == nil then
      storage.station_update_table = nil
      game.print({ "vtm.station-refresh-end" })
    end
  end
  if storage.station_refresh == "init" then
    storage.station_refresh = nil
    backend.init_stations()
  elseif storage.station_refresh == "all" then
    storage.station_refresh = nil
    backend.schedule_station_refresh()
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
        backend.migrate_train_SE(event)
      end
    )
  end
end

function loading()
  on_se_elevator()
end

function setup()
  -- on_tick_n.init()
  init_global_data()
  backend.load_guess_patterns()
  for _, player in pairs(game.players) do
    migrations.init_player_data(player)
    main_gui.create_gui(player)
    local gui_id = gui_utils.get_gui_id(player.index)
    groups.create_gui(gui_id)

    -- do the button thing
    main_gui.add_mod_gui_button(player)
  end
  on_se_elevator()
  storage.station_refresh = "init"
end

-- script.on_event(defines.events.on_gui_opened, function(event)
--   if script.active_mods["debugadapter"] then
--     if event.entity then
--       log("VTM: gui opened" .. event.entity.type)
--     end
--   end
-- end)

-- script.on_event(defines.events.on_gui_closed, function(event)
--   if script.active_mods["debugadapter"] then
--     if event.entity and event.entity.type == "train-stop" then
--       log("VTM: gui closed" .. event.entity.type)
--     end
--   end
-- end)

-- function vtm_open(event)
--   main_gui.open_or_close_gui(event.player_index)
-- end

function vtm_groups_key(event)
  groups.toggle_groups_gui(event.player_index)
end

-- move to corresponding files
function on_lua_shortcut(event)
  -- if event.prototype_name == "vtm-shortcut" then
  --   main_gui.open_or_close_gui(event.player_index)
    if event.prototype_name == "vtm-groups-shortcut" then
    groups.toggle_groups_gui(event.player_index)
  end
end

function on_player_created(event)
  local player = game.players[event.player_index]
  migrations.init_player_data(player)
  main_gui.create_gui(player)
  main_gui.add_mod_gui_button(player)
  local gui_id = gui_utils.get_gui_id(player.index)
  groups.create_gui(gui_id)
end

function on_runtime_mod_setting_changed(event)
  if tables.find({
        "vtm-requester-names",
        "vtm-provider-names",
        "vtm-depot-names",
        "vtm-refuel-names",
        "vtm-p-or-r-start",
      }, event["setting"])
  then
    backend.load_guess_patterns()
    storage.station_refresh = "all"
  end
  if event["setting"] == "vtm-showModgui" then
    local player = game.players[event.player_index]
    if settings.get_player_settings(event.player_index)["vtm-showModgui"].value == false then
      main_gui.remove_mod_gui_button(player)
    else
      main_gui.add_mod_gui_button(player)
    end
  end
  --refresh cached settings
  gui_utils.cache_generic_settings()
end

control.on_init = setup
control.on_load = loading
control.events = {
  [defines.events.on_runtime_mod_setting_changed] = on_runtime_mod_setting_changed,
  [defines.events.on_player_created] = on_player_created,
  [defines.events.on_lua_shortcut] = on_lua_shortcut,
  [defines.events.on_tick] = on_tick,
  ["vtm-groups-key"] = vtm_groups_key,

}


handler.add_lib(control)
handler.add_lib(require("__flib__/gui"))
handler.add_lib(main_gui)
handler.add_lib(require("__virtm__.scripts.gui.searchbar"))
-- handler.add_lib(require("__virtm__.scripts.gui.trains"))
-- handler.add_lib(require("__virtm__.scripts.gui.stations"))
-- handler.add_lib()
-- handler.add_lib()
-- handler.add_lib()
-- handler.add_lib()

-- COMMANDS
commands.add_command("vtm-show-undef-stations", { "vtm.command-help" }, function(event)
  local player = game.get_player(event.player_index)
  if player == nil then return end
  local force = player.valid and player.force or 1
  local table_index = 0
  force.print({ "vtm.show-undef-stations" })
  force.print({ "", { "vtm.filter-surface" }, ": ", storage.settings[event.player_index].surface })

  for _, station_data in pairs(storage.stations) do
    if station_data.station.valid and
        station_data.force_index == player.force.index and
        station_data.type == "ND" and
        (
          station_data.station.surface.name == storage.settings[event.player_index].surface
          or
          storage.settings[event.player_index].surface == "All"
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
