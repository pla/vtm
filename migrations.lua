local vtm_gui    = require("__vtm__.scripts.gui.main_gui")
local vtm_logic  = require("__vtm__.scripts.vtm_logic")
local gui_util   = require("__vtm__.scripts.gui.utils")
local mod_gui    = require("__core__.lualib.mod-gui")
local constants  = require("__vtm__.scripts.constants")
local groups     = require("__vtm__.scripts.gui.groups")

local migrations = {}

function migrations.generic()
  if global.surfaces == nil or table_size(global.surfaces) < 2 then
    global.surfaces = {
      ["All"] = "All",
      ["nauvis"] = "Nauvis",
    }
  end
  if global.station_refresh ~= "init" then
    vtm_logic.load_guess_patterns()
    vtm_logic.update_all_stations("force")
    game.print("VTM updated stations on config change") --TODO localise

  end

  for _, player in pairs(game.players) do
    if player.valid then
      -- init personal settings
      if global.settings[player.index] == nil then
        migrations.init_player_data(player)
      end
      -- recreate gui
      local gui_id = gui_util.get_gui_id(player.index)
      if gui_id and global.guis[gui_id].group_gui then
        groups.destroy_gui(gui_id)
      end
      if gui_id ~= nil then
        vtm_gui.destroy(gui_id)
      end
      vtm_gui.create_gui(player)
      gui_id = gui_util.get_gui_id(player.index)
      groups.create_gui(gui_id)
      player.print("VTM recreated gui on config change") --TODO localise
      -- script.raise_event(constants.refresh_event, {
      --   player_index = player.index,
      -- })
      -- do the button thing
      migrations.add_mod_gui_button(player)
    end
  end
end

migrations.by_version = {
  ["0.1.2"] = function()
    global.surfaces = {
      -- initial creation
      ["All"] = "All",
      ["nauvis"] = "Nauvis",
    }
  end,
  ["0.1.4"] = function()
    global.groups = {} -- initial creation
    global.group_set = {}
    for _, player in pairs(game.players) do
      if player.valid then
        global.groups[player.force_index] = {}
        global.settings[player.index].group_edit = {}
      end
    end
  end,
}

function migrations.init_player_data(player)
  if player.valid then
    -- init personal settings
    global.settings[player.index] = {
      current_tab = "trains",
      gui_refresh = "",
      surface = "All",
      history_switch = "left",
      group_edit = {}
    }
    if not global.groups[player.force_index] then
      global.groups[player.force_index] = {}
    end
  end
end

function migrations.add_mod_gui_button(player)
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

return migrations
