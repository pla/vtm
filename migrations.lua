local vtm_gui    = require("__virtm__.scripts.gui.main_gui")
local backend  = require("__virtm__.scripts.backend")
local utils      = require("__virtm__.scripts.gui.utils")
local mod_gui    = require("__core__.lualib.mod-gui")
local constants  = require("__virtm__.scripts.constants")
local groups     = require("__virtm__.scripts.gui.groups")

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

      -- recreate gui
      local gui_id = utils.get_gui_id(player.index)
      if gui_id and storage.guis[gui_id].group_gui then
        groups.destroy_gui(gui_id)
      end

      if gui_id ~= nil then
        vtm_gui.destroy(gui_id)
      end

      vtm_gui.create_gui(player)
      gui_id = utils.get_gui_id(player.index)
      groups.create_gui(gui_id)
      player.print({ "vtm.config-change2" })

      -- do the button thing
      migrations.add_mod_gui_button(player)
    end
  end
end

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
      group_edit = {} --[[@type GroupEditData[] ]]
    }
    if not storage.groups[player.force_index] then
      storage.groups[player.force_index] = {}
    end
  end
end

function migrations.add_mod_gui_button(player)
  local button_flow = mod_gui.get_button_flow(player) --[[@type LuaGuiElement]]
  if not settings.player_default["vtm-showModgui"] then
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

return migrations
