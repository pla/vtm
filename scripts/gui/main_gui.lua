local constants  = require("__virtm__.scripts.constants")
local classdef   = require("__virtm__.scripts.classdef")
local flib_gui   = require("__flib__.gui")
local mod_gui    = require("__core__.lualib.mod-gui")

local searchbar  = require("__virtm__.scripts.gui.searchbar")
local trains     = require("__virtm__.scripts.gui.trains")
local space      = require("__virtm__.scripts.gui.space")
local stations   = require("__virtm__.scripts.gui.stations")
local depots     = require("__virtm__.scripts.gui.depots")
local history    = require("__virtm__.scripts.gui.history")
local groups     = require("__virtm__.scripts.gui.groups")
local groups_tab = require("__virtm__.scripts.gui.groups-tab")
local backend    = require("__virtm__.scripts.backend")
local gui_utils  = require("__virtm__.scripts.gui.utils")


local function add_space_tab(tabbed_pane,refs)
  if storage.SA_active then
    refs = flib_gui.add(tabbed_pane, space.build_gui(), refs)
  end
    return refs
end

local main_gui = {}

-- config sprite: side_menu_menu_icon
-- search sprite: search_white
-- refresh sprite: refresh_white
local function header(gui_id)
  return {
    type = "flow",
    style = "flib_titlebar_flow",
    drag_target = "window",
    handler = {
      [defines.events.on_gui_click] = main_gui.center_window,
      [defines.events.on_gui_closed] = main_gui.hide,
    },
    children = {
      {
        type = "label",
        style = "frame_title",
        caption = { "vtm.header" },
        ignored_by_interaction = true
      },
      {
        type = "empty-widget",
        style = "flib_titlebar_drag_handle",
        ignored_by_interaction = true
      },
      {
        type = "sprite-button",
        name = "pin_button",
        style = "frame_action_button",
        mouse_button_filter = { "left" },
        auto_toggle = true,
        sprite = "flib_pin_white",
        -- hovered_sprite = "flib_pin_black",
        -- clicked_sprite = "flib_pin_black",
        handler = { [defines.events.on_gui_click] = main_gui.toggle_pinned },
        tooltip = { "gui.flib-keep-open" }
      },
      {
        type = "sprite-button",
        name = "refresh_button",
        style = "frame_action_button",
        mouse_button_filter = { "left", "right" },
        sprite = "vtm_refresh_white",
        ref = { "titlebar", "refresh_button" },
        handler = { [defines.events.on_gui_click] = main_gui.refresh },
        tooltip = { "vtm.refresh" }
      },
      {
        type = "sprite-button",
        name = "close_button",
        style = "frame_action_button",
        mouse_button_filter = { "left" },
        sprite = "utility/close",
        handler = { [defines.events.on_gui_click] = main_gui.hide },
        tooltip = { "gui.close-instruction" }
      },
    }
  }
end

function main_gui.create_gui(player)
  local gui_id = player.index
  gui_utils.handler = searchbar.apply_filter
  local gui_contents = {
    {
      type = "frame",
      direction = "vertical",
      name = "window",
      style_mods = { minimal_width = constants.gui_window_min_width },
      handler = { [defines.events.on_gui_closed] = main_gui.on_window_closed },
      children = {
        header(gui_id),
        searchbar.build_gui(gui_id),
        {
          type = "frame",
          direction = "vertical",
          style = "inside_deep_frame",
          style_mods = { horizontally_stretchable = true },
          {
            type = "tabbed-pane",
            name = "tabbed_pane",
            style = "vtm_tabbed_pane",
            handler = { [defines.events.on_gui_selected_tab_changed] = main_gui.change_tab },
            -- -- tab trains
            -- trains.build_tab(),
            -- -- -- tab stations
            -- stations.build_stations_tab(),
            -- -- -- tab space
            -- add_space_tab(),
            -- -- -- tab depots
            -- depots.build_tab(),
            -- -- -- tab groups
            -- groups_tab.build_tab(),
            -- -- -- tab history
            -- history.build_tab(),
          }, -- end tabbed pane
        },
      }
    }
  }

  local refs = flib_gui.add(player.gui.screen, gui_contents)
  local tabbed_pane = refs.tabbed_pane
  refs = flib_gui.add(tabbed_pane, trains.build_tab(), refs)
  refs = flib_gui.add(tabbed_pane, stations.build_tab(), refs)
  refs = flib_gui.add(tabbed_pane, depots.build_tab(), refs)
  refs = flib_gui.add(tabbed_pane, groups_tab.build_tab(), refs)
  refs = flib_gui.add(tabbed_pane, history.build_tab(), refs)
  refs = add_space_tab(tabbed_pane, refs)

  local gui_data = {
    gui_id = gui_id,
    gui = refs,
    player = player,
    state = "closed",
    state_groups = "closed",
    pinned = false,
    filter_history = {},
    group_gui = {}
  }
  storage.guis[gui_id] = gui_data
  local tab_list = {}
  for key, value in pairs(refs.tabbed_pane.tabs) do
    tab_list[value.tab.name] = key
  end
  -- refs.titlebar.flow.drag_target = refs.window
  searchbar.update(gui_data)
  -- get and set current tab
  local current_tab = storage.settings[player.index].current_tab
  if tab_list[current_tab] == nil then
    current_tab = "trains"
    storage.settings[player.index].current_tab = current_tab
  end
  refs.tabbed_pane.selected_tab_index = tab_list[current_tab]
  -- center window on initial build
  refs.window.force_auto_center()
  -- hide until requested
  refs.window.visible = false
end

---Toggle auto refresh
---@param gui_data GuiData
---@param to_state string? "off"|"auto"
local function toggle_auto_refresh(gui_data, to_state)
  -- get player settings
  local gui_state = storage.settings[gui_data.player.index]
  if to_state ~= nil then
    -- force given state
    if to_state == "off" then
      gui_state.gui_refresh = ""
      gui_data.gui.refresh_button.toggled = false
    elseif to_state == "auto" then
      gui_state.gui_refresh = "auto"
    end
  else
    -- toggle
    if gui_state.gui_refresh == "auto" then
      gui_state.gui_refresh = ""
    else
      gui_state.gui_refresh = "auto"
    end
  end

  if gui_state.gui_refresh == "auto" then
    gui_data.gui.refresh_button.toggled = true
    gui_data.player.print({ "vtm.auto-refresh-on" })
  else
    gui_data.gui.refresh_button.toggled = false
    gui_data.player.print({ "vtm.auto-refresh-off" })
  end
end

--- @param gui_data GuiData
--- @param event? EventData|EventData.on_gui_click
function main_gui.open(gui_data, event)
  main_gui.dispatch_refresh(gui_data, event)
  gui_data.gui.window.visible = true
  gui_data.state = "open"
  if not gui_data.pinned then
    gui_data.player.opened = gui_data.gui.window
  end
end

--- @param gui_data GuiData
--- @param event? EventData|EventData.on_gui_click
function main_gui.hide(gui_data, event)
  if gui_data.state == "closed" then return end
  gui_data.gui.window.visible = false
  gui_data.state = "closed"
  if storage.settings[gui_data.player.index].gui_refresh == "auto" then
    toggle_auto_refresh(gui_data, "off")
  end
  gui_data.player.opened = nil
end

--- @param gui_data GuiData
--- @param event? EventData|EventData.on_gui_click
function main_gui.destroy(gui_data, event)
  gui_data.gui.window.destroy()
  storage.guis[gui_data.gui_id] = nil
end

--- @param event EventData|EventData.on_lua_shortcut
function main_gui.on_lua_shortcut(event)
  if event.prototype_name == "vtm-shortcut" then
    local gui_data = storage.guis[gui_utils.get_gui_id(event.player_index)]
    main_gui.open_or_close_gui(gui_data, event)
  end
end

--- @param gui_data GuiData
--- @param event? EventData|EventData.CustomInputEvent
function main_gui.open_or_close_gui(gui_data, event)
  if event == nil then
    event = gui_data --[[@as EventData.CustomInputEvent]]

    gui_data = storage.guis[gui_utils.get_gui_id(event.player_index)]
  end
  if gui_data.state ~= "open" then
    main_gui.dispatch_refresh(gui_data, event)
    main_gui.open(gui_data, event)
  else
    main_gui.hide(gui_data, event)
  end
end

--- @param gui_data GuiData
--- @param event EventData|EventData.on_gui_click
function main_gui.toggle_pinned(gui_data, event)
  gui_data.pinned = not gui_data.pinned
  if gui_data.pinned then
    gui_data.gui.close_button.tooltip = { "gui.close" }
    -- gui_data.gui.pin_button.sprite = "flib_pin_black"
    -- gui_data.gui.pin_button.style = "flib_selected_frame_action_button"
    gui_data.player.opened = gui_data.gui.window
    if gui_data.player.opened == gui_data.gui.window then
      gui_data.player.opened = nil
    end
  else
    gui_data.gui.close_button.tooltip = { "gui.close-instruction" }
    -- gui_data.gui.pin_button.sprite = "flib_pin_white"
    -- gui_data.gui.pin_button.style = "frame_action_button"
    gui_data.player.opened = gui_data.gui.window
  end
end

--- @param gui_data GuiData
--- @param event EventData|EventData.on_gui_click
function main_gui.refresh(gui_data, event)
  if (event.control and event.button == defines.mouse_button_type.left) or
      event.button == defines.mouse_button_type.right
  then
    toggle_auto_refresh(gui_data)
  end
  main_gui.dispatch_refresh(gui_data, event)
end

---unspecific refresh
---@param event CustomEventDef
function main_gui.refresh_event(event)
  local gui_data = storage.guis[gui_utils.get_gui_id(event.player_index)]
  main_gui.dispatch_refresh(gui_data, event)
end

function main_gui.dispatch_refresh(gui_data, event)
  if not gui_data then return end
  local current_tab = storage.settings[gui_data.player.index].current_tab
  if not settings.global["vtm-showSpaceTab"].value and current_tab == "space" then
    current_tab = "trains"
  end
  -- refresh all data, the tab badges and then the current tab
  searchbar.update(gui_data)
  trains.update_tab(gui_data, event)
  stations.update_stations_tab(gui_data, event)
  if storage.SA_active and settings.global["vtm-showSpaceTab"].value then
    space.update_tab(gui_data, event)
  end
  depots.update_tab(gui_data, event)
  groups_tab.update_tab(gui_data, event)
  history.update_tab(gui_data, event)
end

function main_gui.remove_mod_gui_button(player)
  local button_flow = mod_gui.get_button_flow(player) --[[@as LuaGuiElement]]
  if button_flow.vtm_button then
    button_flow.vtm_button.destroy()
  end
end

function main_gui.add_mod_gui_button(player)
  local button_flow = mod_gui.get_button_flow(player) --[[@as LuaGuiElement]]
  if not settings.get_player_settings(player)["vtm-showModgui"].value then
    main_gui.remove_mod_gui_button(player)
    return
  end
  if button_flow.vtm_button then
    return
  end

  -- TODO: different style when gui_unifier
  flib_gui.add(button_flow, {
    type = "button",
    name = "vtm_button",
    style = mod_gui.button_style,
    caption = "VTM",
    tooltip = { "vtm.mod-gui-tooltip" },
    handler = main_gui.open_or_close_gui,
  })
end

--- @param gui_data GuiData
--- @param event EventData|EventData.on_gui_click
function main_gui.on_window_closed(gui_data, event)
  if gui_data.pinned then
    return
  end
  main_gui.hide(gui_data, event)
end

--- @param gui_data GuiData
--- @param event EventData|EventData.on_gui_click
function main_gui.change_tab(gui_data, event)
  storage.settings[event.player_index].current_tab = event.element.tabs[event.element.selected_tab_index].tab.name
  main_gui.dispatch_refresh(gui_data, event)
end

--- @param gui_data GuiData
--- @param event EventData|EventData.on_gui_click
function main_gui.center_window(gui_data, event)
  if event and event.button and not gui_utils.mouse_button_filter(event.button, "middle") then
    return
  end
  gui_data.gui.window.force_auto_center()
end

flib_gui.add_handlers(main_gui, function(event, handler)
  local gui_id = gui_utils.get_gui_id(event.player_index)
  ---@type GuiData
  local gui_data = storage.guis[gui_id]
  if gui_data then
    handler(gui_data, event)
  end
end, "main_gui")

flib_gui.handle_events()

if not constants.refresh_event then
  constants.refresh_event = script.generate_event_name()
end

main_gui.events = {
  [constants.refresh_event] = main_gui.refresh_event,
  ["vtm-key"] = main_gui.open_or_close_gui,
  [defines.events.on_lua_shortcut] = main_gui.on_lua_shortcut,
}

return main_gui
