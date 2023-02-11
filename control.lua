local tables = require("__flib__.table")
local on_tick_n = require("__flib__.on-tick-n")
local constants = require("__vtm__.scripts.constants")
local vtm_gui = require("__vtm__.scripts.gui.main_gui")
local vtm_logic = require("__vtm__.scripts.vtm_logic")
local gui_util = require("__vtm__.scripts.gui.utils")
local mod_gui = require("__core__.lualib.mod-gui")
local migration = require("__flib__/migration")
local migrations = require("__vtm__/migrations")

DEBUG = true
function LOG(msg)
  if __DebugAdapter or DEBUG then
    log({ "", "[" .. game.tick .. "] ", msg })
  end
end


local function init_global_data()
  global.guis = {}
  global.history = {}
  global.trains = {}
  global.stations = {}
  global.settings = {}
  global.groups = {}
  global.surfaces = {
      ["All"] = "All",
      ["nauvis"] = "Nauvis",
  }
end

local function remove_mod_gui_button(player)
  local button_flow = mod_gui.get_button_flow(player) --[[@as LuaGuiElement]]
  if button_flow.vtm_button then
    button_flow.vtm_button.destroy()
  end
end

migration.handle_on_configuration_changed(migrations.by_version, migrations.generic)


-- local function on_configuration_changed(event)
--   for _, player in pairs(game.players) do
--     if player.valid then
--       -- init personal settings
--       if global.settings[player.index] == nil then
--         migrations.init_player_data(player)
--       end
--       -- recreate gui
--       local gui_id = gui_util.get_gui_id(player.index)
--       if gui_id ~= nil then
--         vtm_gui.destroy(player.index)
--       end
--       vtm_gui.create_gui(player)
--       script.raise_event(constants.refresh_event, {
--           player_index = player.index,
--       })
--       -- do the button thing
--       add_mod_gui_button(player)
--     end
--   end
--   if global.station_refresh == "init" then
--     return
--   end
--   vtm_logic.load_guess_patterns()
--   vtm_logic.update_all_stations("force")
-- end

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
    if global.station_k == nil then
      game.print({ "vtm.station-refresh-end" })
    end
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
--- @class on_train_teleported
--- @field train LuaTrain
--- @field old_train_id_1 uint?
--- @field old_surface_index uint

local function on_se_elevator()
  if
      script.active_mods["space-exploration"]
      and remote.interfaces["space-exploration"]["get_on_train_teleport_started_event"]
  then
    script.on_event(
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
    -- do the button thing
    migrations.add_mod_gui_button(player)

  end
  on_se_elevator()
  global.station_refresh = "init"
end)

-- script.on_event(defines.events.on_gui_opened, function(event)
--   if event.entity and event.entity.type == "train-stop" then
--     -- game.print("gui opened" .. event.entity.type)
--   end
-- end)

-- script.on_event(defines.events.on_gui_closed, function(event)
--   if event.entity and event.entity.type == "train-stop" then
--     -- game.print("gui closed" .. event.entity.type, { 0.5, 0, 0, 0.5 })
--   end
-- end)

script.on_event("vtm-open", function(event)
  vtm_gui.open_or_close_gui(game.players[event.player_index])
end)

script.on_event(defines.events.on_lua_shortcut, function(event)
  if event.prototype_name == "vtm-open" then
    vtm_gui.open_or_close_gui(game.players[event.player_index])
  end
end)

-- script.on_configuration_changed(function(event)
--   on_configuration_changed(event)
-- end)

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
    global.station_refresh = "all"
  end
  if event["setting"] == "vtm-showModgui" then
    local player = game.players[event.player_index]
    if settings.get_player_settings(event.player_index)["vtm-showModgui"].value == false then
      remove_mod_gui_button(player)
    else
      migrations.add_mod_gui_button(player)
    end
  end
end)


-- COMMANDS
commands.add_command("vtm-show-undef-stations", { "vtm.command-help" }, function(event)
  local player = game.get_player(event.player_index)
  if player == nil then return end
  local force = player.valid and player.force or 1
  local table_index = 0
  force.print({ "vtm.show-undef-stations" })
  if script.active_mods["space-exploration"] then
    force.print({ "", { "vtm.filter-surface" }, ": ", global.settings[event.player_index].surface })
  end

  for _, station_data in pairs(global.stations) do
    if station_data.station.valid and
        station_data.force_index == player.force.index and
        station_data.type == "ND" and
        (
        script.active_mods["space-exploration"] and
        station_data.station.surface.name == global.settings[event.player_index].surface
        or
        script.active_mods["space-exploration"] and
        global.settings[event.player_index].surface == "All"
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
  player.print("History Records: " .. table_size(global.history))

end)
