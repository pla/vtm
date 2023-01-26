local constants   = require("scripts.constants")
local gui         = require("__flib__.gui")
local searchbar   = require("scripts.gui.searchbar")
local trains      = require("scripts.gui.trains")
local stations    = require("scripts.gui.stations")
local depots      = require("scripts.gui.depots")
local history     = require("scripts.gui.history")
local vtm_logic   = require("scripts.vtm_logic")
local gui_util    = require("scripts.gui.utils")
local time_filter = require("scripts.filter-time")

-- config sprite: side_menu_menu_icon
-- search sprite: search_white
-- refresh sprite: refresh_white
local function header(gui_id)
  return {
    type = "flow",
    ref = { "titlebar", "flow" },
    children = {
      { type = "label", style = "frame_title", caption = { "vtm.header" }, ignored_by_interaction = true },
      { type = "empty-widget", style = "flib_titlebar_drag_handle", ignored_by_interaction = true },
      {
        type = "sprite-button",
        name = "pin_button",
        style = "frame_action_button",
        sprite = "flib_pin_white",
        hovered_sprite = "flib_pin_black",
        clicked_sprite = "flib_pin_black",
        ref = { "titlebar", "pin_button" },
        actions = {
          on_click = { type = "generic", action = "toggle_pinned", gui_id = gui_id },
        },
        tooltip = { "gui.flib-keep-open" }
      },
      {
        type = "sprite-button",
        name = "refresh_button",
        style = "frame_action_button",
        sprite = "vtm_refresh_white",
        hovered_sprite = "vtm_refresh_black",
        clicked_sprite = "vtm_refresh_black",
        ref = { "titlebar", "refresh_button" },
        actions = {
          on_click = { type = "generic", action = "refresh", gui_id = gui_id },
        },
        tooltip = { "vtm.refresh" }
      },
      {
        type = "sprite-button",
        name = "close_button",
        style = "frame_action_button",
        sprite = "utility/close_white",
        hovered_sprite = "utility/close_black",
        clicked_sprite = "utility/close_black",
        ref = { "titlebar", "close_button" },
        actions = {
          on_click = { type = "generic", action = "close-window", gui_id = gui_id },
        },
        tooltip = { "gui.close-instruction" }

      }
    }
  }
end

local function create_gui(player)
  local gui_id = player.index
  local gui_contents = {
    {
      type = "frame",
      direction = "vertical",
      name = "vtm_main_frame",
      style_mods = { minimal_width = constants.gui_window_min_width },
      ref = { "window" },
      actions = {
        on_closed = { type = "generic", action = "window_closed", gui_id = gui_id }
      },
      children = {
        header(gui_id),
        searchbar.build_gui(gui_id),
        {
          type = "frame",
          direction = "vertical",
          style = "inside_deep_frame_for_tabs",
          style_mods = { horizontally_stretchable = true },
          {
            type = "tabbed-pane",
            ref = { "tabs", "pane" },
            style = "vtm_tabbed_pane",
            -- tab trains
            trains.build_gui(),
            -- tab stations
            stations.build_gui(),
            -- tab depots
            depots.build_gui(),
            -- tab history
            history.build_gui(),
            -- tab statistic
            -- {
            --   tab = {
            --     type = "tab",
            --     caption = { "vtm.tab-statistic" },
            --     ref = { "tabs", "statistic_tab" },
            --     name = "statistic",
            --     actions = {
            --       on_click = { type = "generic", action = "change_tab", tab = "statistic" },
            --     },
            --   },
            --   content = {
            --     type = "flow",
            --     direction = "vertical",
            --     ref = { "tabs", "statistic_contents" },
            --   }
            -- },

          }, -- end tabbed pane
        },
      }
    }
  }
  local vgui = gui.build(player.gui.screen, gui_contents)
  global.guis[gui_id] = {
    gui_id = gui_id,
    gui = vgui,
    player = player,
    state = "closed"
  }
  local tab_list = {}
  for key, value in pairs(vgui.tabs.pane.tabs) do
    tab_list[value.tab.name] = key
  end
  constants.tabs = tab_list
  vgui.titlebar.flow.drag_target = vgui.window
  local current_tab = global.settings[player.index].current_tab or "trains"
  vgui.tabs.pane.selected_tab_index = constants.tabs[current_tab]
  vgui.window.force_auto_center()
  vgui.window.visible = false

end

local function toggle_auto_refresh(gui_id, to_state)
  local vtm_gui = global.guis[gui_id]
  local settings = global.settings[vtm_gui.player.index]
  if to_state ~= nil then
    if to_state == "off" then
      settings.gui_refresh = ""
    elseif to_state == "auto" then
      settings.gui_refresh = "auto"
    end
  else
    -- toggle
    if settings.gui_refresh == "auto" then
      settings.gui_refresh = ""
    else
      settings.gui_refresh = "auto"
    end
  end

  if settings.gui_refresh == "auto" then
    -- vtm_gui.gui.titlebar.refresh_button.tooltip = { "gui.close" }
    vtm_gui.gui.titlebar.refresh_button.sprite = "vtm_refresh_black"
    vtm_gui.gui.titlebar.refresh_button.style = "flib_selected_frame_action_button"
    vtm_gui.player.print({ "vtm.auto-refresh-on" })
  else
    -- vtm_gui.gui.titlebar.refresh_button.tooltip = { "gui.close-instruction" }
    vtm_gui.gui.titlebar.refresh_button.sprite = "vtm_refresh_white"
    vtm_gui.gui.titlebar.refresh_button.style = "frame_action_button"
    vtm_gui.player.print({ "vtm.auto-refresh-off" })
  end
end

local function open_gui(gui_id)
  local vtm_gui = global.guis[gui_id]
  vtm_gui.gui.window.visible = true
  vtm_gui.state = "open"
  if not vtm_gui.pinned then
    vtm_gui.player.opened = vtm_gui.gui.window
  end

end

local function close_gui(gui_id)
  local vtm_gui = global.guis[gui_id]
  if vtm_gui.state == "closed" then return end
  vtm_gui.gui.window.visible = false
  vtm_gui.state = "closed"
  if global.settings[vtm_gui.player.index].gui_refresh == "auto" then
    toggle_auto_refresh(gui_id, "off")
  end
  vtm_gui.player.opened = nil

end

local function destroy_gui(gui_id)
  local vtm_gui = global.guis[gui_id]
  vtm_gui.gui.window.destroy()
  global.guis[gui_id] = nil
end

local function open_or_close_gui(player)
  local gui_id = gui_util.get_gui_id(player.index)
  if gui_id ~= nil then
    local vtm_gui = global.guis[gui_id]
    if vtm_gui.state ~= "open" then
      -- refresh tab before open
      script.raise_event(constants.refresh_event, {
        player_index = player.index,
      })
      open_gui(gui_id)
    else
      close_gui(gui_id)
    end
  end
end

local function toggle_pinned(event)
  local vtm_gui = global.guis[gui_util.get_gui_id(event.player_index)]
  vtm_gui.pinned = not vtm_gui.pinned
  if vtm_gui.pinned then
    vtm_gui.gui.titlebar.close_button.tooltip = { "gui.close" }
    vtm_gui.gui.titlebar.pin_button.sprite = "flib_pin_black"
    vtm_gui.gui.titlebar.pin_button.style = "flib_selected_frame_action_button"
    vtm_gui.player.opened = vtm_gui.gui.window
    if vtm_gui.player.opened == vtm_gui.gui.window then
      vtm_gui.player.opened = nil
    end
  else
    vtm_gui.gui.titlebar.close_button.tooltip = { "gui.close-instruction" }
    vtm_gui.gui.titlebar.pin_button.sprite = "flib_pin_white"
    vtm_gui.gui.titlebar.pin_button.style = "frame_action_button"
    vtm_gui.player.opened = vtm_gui.gui.window
  end
end

--- @class CustomEventDef
--- @field player_index uint
--- @field action table

--- @param event CustomEventDef|table
--- @param action? any
local function dispatch_refresh(event, action)
  local gui_id = gui_util.get_gui_id(event.player_index)
  local player = game.get_player(event.player_index)
  local settings = global.settings[event.player_index]
  if gui_id == nil then
    return --no gui
  end
  if (event.control and event.button == defines.mouse_button_type.left) or
      event.button == defines.mouse_button_type.right
  then
    toggle_auto_refresh(gui_id)
  end
  if action then
    -- gui_id = action.gui_id
  end

  local current_tab = global.settings[event.player_index].current_tab
  if current_tab == "stations" then
    stations.update_tab(gui_id)
  elseif current_tab == "trains" then
    trains.update_tab(gui_id)
  elseif current_tab == "depots" then
    depots.update_tab(gui_id)
  elseif current_tab == "history" then
    history.update_tab(gui_id)
  elseif current_tab == "requests" then
  elseif current_tab == "statistic" then
  end

end

local function handle_action(action, event)
  if action.action == "close-window" then -- x button
    close_gui(action.gui_id)
  elseif action.action == "window_closed" then
    if global.guis[action.gui_id].pinned then
      return
    end
    close_gui(action.gui_id)
  elseif action.action == "clear_history" then
    -- delete history older 2 mins
    local older_than = game.tick - time_filter.ticks(1)
    vtm_logic.clear_older(event.player_index, older_than)
    dispatch_refresh(event)
  elseif action.action == "change_tab" then
    global.settings[event.player_index].current_tab = action.tab
    dispatch_refresh(event)
  elseif action.action == "refresh" then
    dispatch_refresh(event, action)
  elseif action.action == "toggle_pinned" then
    toggle_pinned(event)
  elseif action.action == "open-vtm" then -- mod-gui-button
    local player = game.players[event.player_index]
    open_or_close_gui(player)
  end
end

gui.hook_events(function(event)
  local action = gui.read_action(event)
  if action then
    if action.type == "generic" then
      handle_action(action, event)
    elseif action.type == "trains" then
      trains.handle_action(action, event)
    elseif action.type == "stations" then
      stations.handle_action(action, event)
    elseif action.type == "depots" then
      depots.handle_action(action, event)
    elseif action.type == "searchbar" then
      searchbar.handle_action(action, event)
    elseif action.type == "history" then
      history.handle_action(action, event)
    end
  end
end)

if not constants.refresh_event then
  constants.refresh_event = script.generate_event_name()
end

script.on_event(constants.refresh_event, function(event)
  dispatch_refresh(event)
end)

return {
  open_or_close_gui = open_or_close_gui,
  open = open_gui,
  close = close_gui,
  destroy = destroy_gui,
  create_gui = create_gui,
}
