local main_gui = require("__virtm__.scripts.gui.main_gui")
local backend = require("__virtm__.scripts.backend")
local utils = require("__virtm__.scripts.gui.utils")
local groups = require("__virtm__.scripts.gui.groups")

local migrations = {}

function migrations.generic()
  --refresh cached settings
  utils.cache_generic_settings()

  if storage.surfaces == nil or table_size(storage.surfaces) < 1 then
    storage.surfaces = {
      ["All"] = "All",
    }
  end
  if storage.station_refresh ~= "init" then
    backend.load_guess_patterns()
    backend.update_all_stations("force")
    game.print({ "vtm.config-change1" })
  end

  for _, player in pairs(game.players) do
    if player.valid then
      -- init personal settings
      if storage.settings[player.index] == nil then
        migrations.init_player_data(player)
      end
      -- init pin_groups if not already available
      if storage.settings[player.index].groups_tab_pinned == nil then
        storage.settings[player.index].groups_tab_pinned = {}
      end
      -- recreate gui
      local gui_id = utils.get_gui_id(player.index)
      local gui_data
      if gui_id then
        gui_data = storage.guis[gui_id]
      end
      if gui_data and gui_data.group_gui then
        groups.destroy_gui(gui_data)
      end

      if gui_data ~= nil then
        main_gui.destroy(gui_data)
      end

      main_gui.create_gui(player)
      gui_id = utils.get_gui_id(player.index)
      gui_data = storage.guis[gui_id]
      groups.create_gui(gui_data)
      player.print({ "vtm.config-change2" })

      -- do the button thing
      main_gui.add_mod_gui_button(player)
    end
  end
end

-- legacy, but stays so I don't have to relearn how to do this in the future
migrations.by_version = {
  ["0.1.2"] = function()
    storage.surfaces = {
      -- initial creation
      ["All"] = "All",
    }
  end,
  ["0.1.4"] = function()
    storage.groups = {} -- initial creation
    storage.group_set = {}
    for _, player in pairs(game.players) do
      if player.valid then
        storage.groups[player.force_index] = {}
        storage.settings[player.index].group_edit = {}
      end
    end
  end,
}

function migrations.init_player_data(player)
  if player.valid then
    -- init personal settings
    storage.settings[player.index] = {
      current_tab = "trains",
      gui_refresh = "",
      surface = "All",
      history_switch = "left",
      group_edit = {} --[[@type GroupEditData[] ]],
      groups_tab_pinned = {},
    }
    if not storage.groups[player.force_index] then
      storage.groups[player.force_index] = {}
    end
  end
end

return migrations
