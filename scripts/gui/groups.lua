-- groups.lua station groups
local table     = require("__flib__.table")
local gui       = require("__flib__.gui")
local gui_util  = require("__vtm__.scripts.gui.utils")
local util      = require("__core__.lualib.util")
local constants = require("__vtm__.scripts.constants")
local vtm_logic = require("__vtm__.scripts.vtm_logic")
local flib_box  = require("__flib__.bounding-box")



-- config sprite: side_menu_menu_icon
-- search sprite: search_white
-- refresh sprite: refresh_white
local function header(gui_id)
  return {
    type = "flow",
    ref = { "titlebar", "flow" },
    children = {
      {
        type = "label",
        style = "frame_title",
        caption = { "vtm.groups-header-create" },
        ignored_by_interaction = true
      },
      {
        type = "empty-widget",
        style = "flib_titlebar_drag_handle",
        ignored_by_interaction = true
      },
      {
        type = "sprite-button",
        name = "close_button",
        style = "frame_action_button",
        sprite = "utility/close_white",
        mouse_button_filter = { "left" },
        hovered_sprite = "utility/close_black",
        clicked_sprite = "utility/close_black",
        ref = { "titlebar", "close_button" },
        actions = {
          on_click = { type = "groups", action = "close-window", gui_id = gui_id },
        },
        tooltip = { "gui.close" }
      }
    }
  }
end

local function dialog_buttons(gui_id)
  return {
    type = "flow",
    style = "dialog_buttons_horizontal_flow",
    -- ref = { "dialog_buttons", "flow" },
    children = {
      {
        type = "button",
        style = "back_button",
        caption = { "gui.clear" },
        mouse_button_filter = { "left" },
        ref = { "dialog_buttons", "left" },
        actions = {
          on_click = { type = "groups", action = "clear", gui_id = gui_id },
        },
      },
      {
        type = "empty-widget",
        style = "flib_horizontal_pusher",
        ignored_by_interaction = true
      },
      {
        type = "button",
        style = "dialog_button",
        mouse_button_filter = { "left", "right" },
        ref = { "dialog_buttons", "middle" },
        caption = { "gui-permissions-names.SelectArea" },
        tooltip = { "vtm.groups-select-area" },
        actions = {
          on_click = { type = "groups", action = "select_area", gui_id = gui_id },
        },
      },
      {
        type = "empty-widget",
        style = "flib_horizontal_pusher",
        ignored_by_interaction = true
      },
      {
        type = "button",
        style = "confirm_button",
        caption = { "gui.save" },
        tooltip = { "vtm.groups-save-and-clear" },
        mouse_button_filter = { "left" },
        ref = { "dialog_buttons", "right" },
        actions = {
          on_click = { type = "groups", action = "save", gui_id = gui_id },
        },
      },
    }
  }
end


local function build_top_buttons(gui_id)
  local content = {
    {
      type = "empty-widget",
      style = "flib_horizontal_pusher",
      ignored_by_interaction = true
    },
    {
      type = "sprite-button",
      style = "tool_button",
      sprite = "utility/clone",
      mouse_button_filter = { "left" },
      name = "overlay_button",
      tooltip = { "vtm.groups-toggle-overlay-tooltip" },
      ref = { "top_buttons", "overlay_button" },
      actions = {
        on_click = { type = "groups", action = "toggle_overlay", gui_id = gui_id },
      },
    },
    {
      type = "sprite-button",
      style = "tool_button",
      sprite = "utility/area_icon",
      name = "toggle_mode_button",
      mouse_button_filter = { "left" },
      tooltip = { "vtm.groups-toggle-additive-selection-tooltip" },
      ref = { "top_buttons", "toggle_mode_button" },
      enabled = true,
      actions = {
        on_click = { type = "groups", action = "toggle_mode_button", gui_id = gui_id },
      },
    },
    {
      type = "sprite-button",
      style = "tool_button",
      sprite = "utility/close_black",
      name = "remove_button",
      tooltip = { "vtm.groups-remove-station-tooltip" },
      mouse_button_filter = { "left" },
      ref = { "top_buttons", "remove_button" },
      enabled = false,
      actions = {
        on_click = { type = "groups", action = "remove_station", gui_id = gui_id },
      },
    },
    {
      type = "sprite-button",
      style = "tool_button",
      sprite = "utility/reset",
      name = "reload_grp_button",
      tooltip = { "vtm.groups-reload-grp-tooltip" },
      mouse_button_filter = { "left" },
      ref = { "top_buttons", "reload_grp_button" },
      enabled = false,
      actions = {
        on_click = { type = "groups", action = "reload_grp", gui_id = gui_id },
      },
    },
    {
      type = "sprite-button",
      style = "tool_button_red",
      sprite = "utility/trash",
      name = "delgrp_button",
      tooltip = { "vtm.groups-delete-group-tooltip" },
      mouse_button_filter = { "left" },
      ref = { "top_buttons", "delgrp_button" },
      enabled = false,
      actions = {
        on_click = { type = "groups", action = "delgrp", gui_id = gui_id },
      },
    },

  }
  return content
end
local function build_gui(gui_id, name)
  local width = constants.gui.groups
  if name == nil then
    name = "vtm_groups"
  end
  return {
    {
      type = "frame",
      direction = "vertical",
      name = name,
      style_mods = { minimal_width = width.window_min_width },
      ref = { "groups_window" },
      actions = {
        on_closed = { type = "groups", action = "window_closed", gui_id = gui_id }
      },
      children = {
        header(gui_id),
        {
          -- main content frame
          type = "frame",
          style = "inside_deep_frame",
          direction = "vertical",
          {
            type = "frame",
            style = "subheader_frame",
            direction = "horizontal",
            ref = { "groups", "top_header" },
            style_mods = { horizontally_stretchable = true, horizontal_align = "right" },
            children = build_top_buttons(gui_id),
          },
          gui_util.default_list_box("top_list",
            { type = "groups", action = "select_element", gui_id = gui_id },
            nil, width.top_rows,
            { "top_list" },
            "list_box_under_subheader"
          ),
          {
            type = "line",
            direction = "horizontal",
          },
          {
            type = "frame",
            style = "subheader_frame",
            direction = "horizontal",
            ref = { "bottom_header" },
            style_mods = { horizontally_stretchable = true },
          },
          gui_util.default_list_box("bottom_list",
            { type = "groups", action = "select_element", gui_id = gui_id },
            nil, width.bottom_rows,
            { "bottom_list" },
            "list_box_under_subheader"
          ),
        },
        dialog_buttons(gui_id),
      }
    }
  }
end

local function create_gui(gui_id)
  local vtm_gui = global.guis[gui_id]
  local player = vtm_gui.player
  if global.groups[player.index] == nil then
    global.groups[player.index] = {}
  end
  local ui = build_gui(gui_id)
  local refs = gui.build(player.gui.screen, ui)
  refs.titlebar.flow.drag_target = refs.groups_window
  refs.groups_window.visible = false
  global.guis[gui_id].group_gui = refs
  global.guis[gui_id].state_groups = "closed"
  gui.update(refs.groups_window, {
    elem_mods = {
      location = { 10, 150 }
    }
  })
end

local function split_stations(stations)
  ---@type table<uint,LuaEntity>
  local provider = {}
  ---@type table<uint,LuaEntity>
  local requester = {}
  for _, station in pairs(stations or {}) do
    if global.stations[station.unit_number].type == "P" then
      table.insert(provider, station)
    elseif global.stations[station.unit_number].type == "R" then
      table.insert(requester, station)
    end
  end
  return provider, requester
end

---merge to lists of stations entities
---@param stations table<uint,LuaEntity>
---@param new_stations table<uint,LuaEntity>
local function merge_station_list(stations, new_stations)
  for _, new in pairs(new_stations) do
    if not stations[new.unit_number] then
      stations[new.unit_number] = new
    end
  end
end

---merge tags to a tag list
---@param tags table<uint,LuaCustomChartTag>
---@param new_tags table<uint,LuaCustomChartTag>
local function merge_tag_list(tags, new_tags)
  for _, new in pairs(new_tags or {}) do
    if not tags[new.tag_number] then
      tags[new.tag_number] = new
    end
  end
end

--- clear all temp data
---@param gui_id uint
local function clear_selected_data(gui_id)
  local vgui = global.guis[gui_id]
  local group_gui = vgui.group_gui
  if not group_gui then return end
  local top_buttons = group_gui.top_buttons
  local top_list = group_gui.top_list
  local bottom_list = group_gui.bottom_list
  local edit = global.settings[vgui.player.index].group_edit
  edit.selected_stations = nil
  edit.selected_tags = nil
  edit.selected_group_id = nil
  edit.group_area = nil
  top_list.selected_index = 0
  bottom_list.selected_index = 0
  top_buttons.reload_grp_button.enabled = false
  top_buttons.remove_button.enabled = false
end
local function remove_group_tags(player)
  if not global.group_tags or not player then return end
  local force = player.force
  if not global.group_tags[force.index] then return end
  -- local surface = player.surface.name
  -- only one surface, and one user per force can show tags, to keep it simple
  for _, tag in pairs(global.group_tags[force.index]) do
    if tag.valid then
      tag.destroy()
    end
  end
  global.group_tags[force.index] = {}
end

---create a chart tag
---@param force LuaForce
---@param surface SurfaceIdentification
---@param position MapPosition
---@param text string?
---@param player_index uint
---@return LuaCustomChartTag?
local function create_map_tag(force, surface, position, text, player_index)
  local tag
  tag = force.add_chart_tag(surface, {
    position = position,
    icon = { type = "virtual", name = "signal-check" },
    text = tostring(text),
    last_user = player_index
  })
  if tag and tag.valid then
    table.insert(global.group_tags[force.index], tag)
  end
  return tag
end

local function create_group_tags(gui_id)
  local vgui = global.guis[gui_id]
  local player = vgui.player
  local force = player.force --[[@as LuaForce]]
  local surface = player.surface.name

  if not global.group_tags then
    global.group_tags = {}
  end
  if not global.group_tags[force.index] then
    global.group_tags[force.index] = {}
  end

  for group_id, group in pairs(global.groups[force.index]) do
    -- if group.main_station and group.main_station.station.valid then
    if group.surface == surface then
      local position = flib_box.center(group.area)
      local tag = create_map_tag(force, surface, position, tostring(group.group_id), player.index)
    end
    -- end
  end
end

---draw ovleray rectangle
---@param color Color
---@param surface SurfaceIdentification
---@param area BoundingBox
---@param ttl uint?
---@return uint64
local function draw_group_rectangle(color, surface, area, ttl)
  local id = rendering.draw_rectangle({
    color = color,
    filled = false,
    surface = surface,
    width = 32,
    left_top = area.left_top,
    right_bottom = area.right_bottom,
    time_to_live = ttl, --600ticks=10sec
  })
  return id
end
local function show_overlay(gui_id)
  local vgui = global.guis[gui_id]
  local player = vgui.player
  local surface = player.surface.name
  for _, group in pairs(global.groups[player.force_index]) do
    if group.surface == surface then
      -- local id = rendering.draw_rectangle({
      --   color = constants.blue,
      --   filled = false,
      --   surface = group.surface,
      --   width = 32,
      --   left_top = group.area.left_top,
      --   right_bottom = group.area.right_bottom,
      --   time_to_live = 600, --600ticks=10sec
      -- })
      local id = draw_group_rectangle(constants.blue, group.surface, group.area)
    end
  end
end

local function remove_overlay()
  -- FIXME this will clear all overlays of all players, maybe there is a better solution to this
  rendering.clear(script.mod_name)
end

---Toggle overlay button
---@param action GuiAction
---@param event EventData.on_gui_click
local function toggle_overlay(action, event)
  local edit = global.settings[event.player_index].group_edit
  if edit and edit.show_overlay then
    event.element.style = "tool_button"
    edit.show_overlay = false
    remove_overlay()
    remove_group_tags(game.get_player(event.player_index))
  else
    event.element.style = "flib_selected_tool_button"
    edit.show_overlay = true
    show_overlay(action.gui_id)
    create_group_tags(action.gui_id)
  end
end

---update Edit group dialog
---@param gui_id uint
---@param station_list_temp? table<uint,LuaEntity>
local function update_gui(gui_id, station_list_temp)
  local vtm_gui = global.guis[gui_id]
  local surface = global.settings[vtm_gui.player.index].surface or "All"
  local top_buttons = vtm_gui.group_gui.top_buttons
  local edit = global.settings[vtm_gui.player.index].group_edit

  local top_names = {}
  local bottom_names = {}
  local top_list = vtm_gui.group_gui.top_list
  local bottom_list = vtm_gui.group_gui.bottom_list
  local provider = {}
  local requester = {}
  local top_index = 0
  local bottom_index = 0
  local station_list = edit.selected_stations
  local tag_list = edit.selected_tags

  if station_list then
    provider, requester = split_stations(station_list)
  end

  for _, station in pairs(provider) do
    top_index = top_index + 1
    --check for existing group
    local name = station.backer_name
    if global.groups[station.force_index][station.unit_number] then
      name = name .. constants.group_exist_suffix
    end
    table.insert(top_names, name)
  end
  for _, station in pairs(requester) do
    bottom_index = bottom_index + 1
    table.insert(bottom_names, station.backer_name)
  end
  for _, tag in pairs(tag_list or {}) do
    bottom_index = bottom_index + 1
    table.insert(bottom_names, tag.text)
  end

  top_list.items = #top_names > 0 and top_names or {}
  top_list.selected_index = 0
  bottom_list.items = #bottom_names > 0 and bottom_names or {}
  bottom_list.selected_index = 0
  top_buttons.remove_button.enabled = false
  top_buttons.delgrp_button.enabled = false
  if edit.selected_group_id then
    top_buttons.reload_grp_button.enabled = true
  else
    top_buttons.reload_grp_button.enabled = false
  end
  if edit.show_overlay then
    top_buttons.overlay_button.style = "flib_selected_tool_button"
  else
    top_buttons.overlay_button.style = "tool_button"
  end
end

---@param gui_id uint
---@param group_id uint
local function update_gui_from_group(gui_id, group_id)
  local vtm_gui = global.guis[gui_id]
  local edit = global.settings[vtm_gui.player.index].group_edit

  if group_id then
    local stations = {}
    local group_data = vtm_logic.read_group(group_id)
    if group_data then
      clear_selected_data(gui_id)
      edit.selected_group_id = group_data.group_id
      edit.selected_stations = {}
      edit.selected_tags = {}
      table.insert(stations, group_data.main_station.station)
      edit.group_area = group_data.area
      for _, station_data in pairs(group_data.members) do
        if station_data.station.valid then
          table.insert(stations, station_data.station)
        end
      end
      merge_station_list(edit.selected_stations, stations)
      merge_tag_list(edit.selected_tags, group_data.resource_tags)
    end
    update_gui(gui_id)
  end
end

---Make groups gui visible, action can contain group_id to show, optional clear argument to remove all content
---@param action GuiAction
---@param clear? boolean
local function open_gui(action, clear)
  local gui_id = action.gui_id
  local gui = global.guis[gui_id]
  gui.group_gui.groups_window.visible = true
  gui.state_groups = "open"
  if action.group_id then
    update_gui_from_group(action.gui_id, action.group_id)
    return
  end
  -- TODO: that might not work anymore
  if clear then
    clear_selected_data(action.gui_id)
  end
  update_gui(action.gui_id)
end

---Create set or add station
---@param name string
---@param group_id uint
local function register_group_set(name, group_id)
  if not name or not group_id then return end
  if not global.group_set[name] then
    global.group_set[name] = {}
  end
  for _, value in pairs(global.group_set[name]) do
    if value == group_id then
      return
    end
  end
  table.insert(global.group_set[name], group_id)
end

---Validate group members and tags
---@param group_edit_data GroupEditData
local function validate_group_data(group_edit_data)
  local stations_ok = true
  local tags_ok = true
  -- validate stations
  for key, station in pairs(group_edit_data.selected_stations or {}) do
    if not station.valid then
      group_edit_data.selected_stations[key] = nil
    end
  end
  --validate tags
  for key, tag in pairs(group_edit_data.selected_tags or {}) do
    if not tag.valid then
      tags_ok = false
      group_edit_data.selected_tags[key] = nil
    end
  end

  return stations_ok and tags_ok
end

---add overlay of saved group, if overlay is enabled
---@param gui_id gui_id
---@param group_data GroupData
---@param show boolean show_overlay
local function add_group_overlay(gui_id, group_data, show)
  if show then
    local vgui = global.guis[gui_id]
    local player = vgui.player
    local force = player.force --[[@as LuaForce]]
    local surface = player.surface.name
    local position = flib_box.center(group_data.area)
    local text = tostring(group_data.group_id)
    local id = draw_group_rectangle(constants.blue, group_data.surface, group_data.area)
    local tag = create_map_tag(force, surface, position, text, player.index)
  end
end

--- Save selceted group data, can be more then one
---@param action GuiAction
---@param event EventData.on_gui_click
local function save_groups(action, event)
  local player = game.get_player(event.player_index)
  if not player then return false end
  local edit = global.settings[event.player_index].group_edit
  -- validate data
  if not validate_group_data(edit) then
    player.create_local_flying_text({
      text = { "vtm.groups-error-saving-group" },
      create_at_cursor = true,
    })
    update_gui(action.gui_id)
    return false
  end

  local tag_list = edit.selected_tags or {}
  local provider, requester = split_stations(edit.selected_stations)
  if #provider == 0 or (#requester == 0 and table_size(tag_list) == 0) then
    player.create_local_flying_text({
      text = { "vtm.groups-error-saving-group" },
      create_at_cursor = true,
    })
    return false
  end
  -- TODO maybe check for surface mismatch
  local group_members = {}

  for _, r_station in pairs(requester) do
    table.insert(group_members, vtm_logic.get_or_create_station_data(r_station))
  end
  for _, p_station in pairs(provider) do
    ---@type GroupData
    local group_data = {
      created = game.tick,
      group_id = p_station.unit_number,
      members = group_members,
      main_station = vtm_logic.get_or_create_station_data(p_station),
      surface = p_station.surface.name,
      area = edit.group_area,
      resource_tags = tag_list,
    }
    global.groups[p_station.force_index][p_station.unit_number] = group_data
    register_group_set(p_station.backer_name, p_station.unit_number)
    player.print({ "vtm.groups-saved", p_station.unit_number })
    add_group_overlay(action.gui_id, group_data, edit.show_overlay)
  end
  --todo maybe option to show last saved group
  clear_selected_data(action.gui_id)
  update_gui(action.gui_id, {})
  return true
end

---Clear edit window
---@param event EventData.on_gui_click
local function clear_selected(action, event)
  clear_selected_data(action.gui_id)
  update_gui(action.gui_id, {})
end

---@param event EventData.on_gui_elem_changed
local function on_gui_elem_changed(event)
  local gui_id      = gui_util.get_gui_id(event.player_index)
  local group_gui   = global.guis[gui_id].group_gui
  ---@type LuaGuiElement
  local top_buttons = group_gui.top_buttons
  ---@type LuaGuiElement
  local top_list    = group_gui.top_list
  ---@type LuaGuiElement
  local bottom_list = group_gui.bottom_list

  if event.element.name == "top_list" then
    bottom_list.selected_index = 0
    -- check for existing group
    local str = top_list.get_item(event.element.selected_index)
    -- enable delgrp_button
    if gui_util.string_ends_with(str, constants.group_exist_suffix) then
      top_buttons.delgrp_button.enabled = true
      gui_util.set_style(top_buttons.delgrp_button, constants.button_style_red)
      top_buttons.reload_grp_button.enabled = true
    else
      top_buttons.delgrp_button.enabled = false
      top_buttons.reload_grp_button.enabled = false
    end
  elseif event.element.name == "bottom_list" then
    top_buttons.delgrp_button.enabled = false
    top_buttons.reload_grp_button.enabled = false
    top_list.selected_index = 0
  end

  if top_list.selected_index > 0 or bottom_list.selected_index > 0 then
    top_buttons.remove_button.enabled = true
  else
    top_buttons.remove_button.enabled = false
  end
end

---Toggle additive selection button
---@param action table
---@param event EventData.on_gui_click
local function toggle_tool_mode_button(action, event)
  local edit = global.settings[event.player_index].group_edit
  if edit and edit.add_to_selection then
    event.element.style = "tool_button"
    edit.add_to_selection = false
  else
    event.element.style = "flib_selected_tool_button"
    edit.add_to_selection = true
  end
end

local function give_selector(player)
  if player.clear_cursor() then
    player.cursor_stack.set_stack({ name = "vtm-station-group-selector" })
    player.cursor_stack_temporary = true
  end
end

local function close_gui(gui_id)
  local vgui = global.guis[gui_id]
  local edit = global.settings[vgui.player.index].group_edit
  local refs = vgui.group_gui
  refs.groups_window.visible = false
  vgui.state_groups = "closed"
  edit.show_overlay = false
  remove_overlay()
  remove_group_tags(vgui.player)
  vgui.player.clear_cursor()
end

local function destroy_gui(gui_id)
  close_gui(gui_id)
  local vgui = global.guis[gui_id]
  vgui.group_gui.groups_window.destroy()
  vgui.group_gui = nil
  clear_selected_data(gui_id)
end

local function toggle_groups_gui(player_index)
  local gui_id = gui_util.get_gui_id(player_index)
  if not gui_id then return end

  if gui_id and
      global.guis[gui_id].state_groups and
      global.guis[gui_id].state_groups == "closed" then
    open_gui({ gui_id = gui_id })
    give_selector(global.guis[gui_id].player)
  else
    close_gui(gui_id)
  end
end

local function remove_station_from_list(action, event)
  local edit                = global.settings[event.player_index].group_edit
  local gui_id              = action.gui_id
  local group_gui           = global.guis[gui_id].group_gui
  local top_buttons         = group_gui.top_buttons
  local top_list            = group_gui.top_list
  local bottom_list         = group_gui.bottom_list
  local provider, requester = split_stations(edit.selected_stations)
  local station

  if top_list.selected_index > 0 then
    local name = top_list.items[top_list.selected_index]
    if util.string_starts_with(name, provider[top_list.selected_index].backer_name) then
      station = provider[top_list.selected_index]
    end
  elseif bottom_list.selected_index > 0 then
    local name = bottom_list.items[bottom_list.selected_index]
    if #requester >= bottom_list.selected_index and
        requester[bottom_list.selected_index].backer_name == name then
      station = requester[bottom_list.selected_index]
    end
    if not station then -- must be a chart tag then
      for key, tag in pairs(edit.selected_tags) do
        if tag.text == name then
          edit.selected_tags[key] = nil
          break
        end
      end
    end
  end
  if station then
    for key, value in pairs(edit.selected_stations) do
      if value.unit_number == station.unit_number then
        edit.selected_stations[key] = nil
        break
      end
    end
  end
  top_buttons.remove_button.enabled = false
  top_buttons.delgrp_button.enabled = false
  top_buttons.reload_grp_button.enabled = false
  top_list.selected_index = 0
  bottom_list.selected_index = 0
  update_gui(action.gui_id, edit.selected_stations)
end

local function remove_group_from_set(station)
  if not station.valid then return end
  local set = global.group_set[station.backer_name]
  if not set then return end
  local remove
  for key, group_id in pairs(set) do
    if group_id == station.unit_number then
      remove = key
    end
  end
  table.remove(set, remove)
  if table_size(set) == 0 then
    global.group_set[station.backer_name] = nil
  end
end

---@param action table
---@param event table
local function delete_group(action, event)
  --two steps
  local edit        = global.settings[event.player_index].group_edit
  local player      = game.get_player(event.player_index)
  local group_gui   = global.guis[action.gui_id].group_gui
  local top_buttons = group_gui.top_buttons
  local button      = top_buttons.delgrp_button
  local top_list    = group_gui.top_list
  local style_red   = constants.button_style_red
  local style_green = constants.button_style_green
  local p_station

  local group_id    = edit.selected_group_id

  if not group_id and top_list.selected_index > 0 then
    for _, station in pairs(edit.selected_stations) do
      local name = top_list.items[top_list.selected_index]
      if util.string_starts_with(name, station.backer_name) then
        p_station = station
        break
      end
    end
  else
    p_station = global.stations[group_id] and global.stations[group_id].station
  end

  if not button or not button.enabled or not p_station or not player then return end

  if button.style.name == style_green then
    gui_util.set_style(button, style_red)
    -- delete set entry
    remove_group_from_set(p_station)
    --delete the group
    global.groups[p_station.force_index][p_station.unit_number] = nil
    clear_selected_data(action.gui_id)
    update_gui(action.gui_id, {})
    player.print({ "vtm.groups-group-deleted", p_station.unit_number })
  elseif button.style.name == style_red then
    gui_util.set_style(button, style_green)
    player.create_local_flying_text({
      text = { "vtm.groups-click-again" },
      time_to_live = 100,
      create_at_cursor = true
    })
  end
end

---@param event EventData.on_player_selected_area
local function extract_train_stops(event)
  local stations = {}
  for _, entity in pairs(event.entities) do
    if entity.type == "train-stop" and entity.name ~= "se-space-elevator" then
      table.insert(stations, entity)
    end
  end
  if next(stations) then
    return stations
  else
    return nil
  end
end

---@param area BoundingBox
---@param stations table<uint,LuaEntity>
---@return BoundingBox
local function check_area(area, stations)
  if not stations then return area end
  for _, station in pairs(stations) do
    if not area then
      area = flib_box.from_position(station.position)
    end
    local check = flib_box.contains_position(area, station.position)
    if not check then
      area = flib_box.expand_to_contain_position(area, station.position)
    end
  end
  return area
end

local function on_alt_station_selection(event)
  local player = game.get_player(event.player_index)
  if player and event.entities then
    local selected_stations = extract_train_stops(event)
    local gui_id = gui_util.get_gui_id(player.index)
    --TODO no elevator
    if selected_stations and gui_id then
      local edit = global.settings[player.index].group_edit
      player.clear_cursor()
      if edit.selected_stations == nil or edit.selected_stations == {} then
        return
      end
      local remove
      local i, entity = next(event.entities, nil)
      while i do
        for key, station in pairs(edit.selected_stations) do
          if station.unit_number == entity.unit_number then
            remove = key
            entity = nil
            break
          end
        end
        i, entity = next(event.entities, i)
        edit.selected_stations[remove] = nil
      end
      update_gui(gui_id, edit.selected_stations)
    else
      player.create_local_flying_text({
        text = { "vtm.no_train_stop_selected" },
        create_at_cursor = true,
      })
    end
  end
end

---filter tags we created ourself
---@param selected_tags LuaCustomChartTag[]
local function filter_own_tags(selected_tags)
  for key, tag in pairs(selected_tags or {}) do
    if tag.icon and tag.icon.name == "signal-check" and tag.icon.type == "virtual" then
      selected_tags[key] = nil
    end
  end
end

---handle tag selection
---@param event EventData.on_player_selected_area
local function on_tag_selection(event)
  local player = game.get_player(event.player_index)
  if not player then return end

  ---@type LuaCustomChartTag[]
  local selected_tags = player.force.find_chart_tags(event.surface, event.area)
  local gui_id = gui_util.get_gui_id(player.index)
  if next(selected_tags) then
    filter_own_tags(selected_tags)
  end
  if next(selected_tags) and gui_id then
    local edit = global.settings[player.index].group_edit
    player.clear_cursor()
    if not edit.add_to_selection or edit.selected_tags == nil then
      edit.selected_tags = {}
    end
    -- merge and store in global
    merge_tag_list(edit.selected_tags, selected_tags)
    update_gui(gui_id)
  end
end

---handle station selection
---@param event EventData.on_player_selected_area
local function on_station_selection(event)
  local player = game.get_player(event.player_index)
  if player and event.entities then
    local selected_stations = extract_train_stops(event)
    local gui_id = gui_util.get_gui_id(player.index)
    if selected_stations and gui_id then
      local edit = global.settings[player.index].group_edit
      if player.mod_settings["vtm-dismiss-tool"].value then
        player.clear_cursor()
      end

      if not edit.add_to_selection or edit.selected_stations == nil then
        edit.selected_stations = {}
      end
      if not edit.group_area then
        edit.group_area = event.area
      end
      -- merge and store in global
      merge_station_list(edit.selected_stations, selected_stations)
      -- ensure all stations are inside the selected area
      edit.group_area = check_area(edit.group_area, edit.selected_stations)
      update_gui(gui_id, edit.selected_stations)
    else
      player.create_local_flying_text({
        text = { "vtm.groups-no-train-stop-selected" },
        create_at_cursor = true,
      })
    end
  end
end

---Station selection
---@param event EventData.on_player_selected_area
local function on_player_selected_area(event)
  if event.item ~= "vtm-station-group-selector" then return end
  on_station_selection(event)
end

---Station selection
---@param event EventData.on_player_selected_area
local function on_player_reverse_selected_area(event)
  if event.item ~= "vtm-station-group-selector" then return end
  on_tag_selection(event)
end

---Station selection
---@param event EventData.on_player_selected_area
local function on_player_alt_selected_area(event)
  if event.item ~= "vtm-station-group-selector" then return end
  on_alt_station_selection(event)
end

local function reload_group(action, event)
  local edit = global.settings[event.player_index].group_edit
  update_gui_from_group(action.gui_id, edit.selected_group_id)
end

---React on user input
---@param action table
---@param event table
local function handle_action(action, event)
  if action.action == "close-window" then
    close_gui(action.gui_id)
  elseif action.action == "select_element" then
    on_gui_elem_changed(event)
  elseif action.action == "select_area" then
    local player = game.get_player(event.player_index)
    if not player then return end
    give_selector(player)
  elseif action.action == "save" then
    save_groups(action, event)
    -- todo give better feedback on error
  elseif action.action == "toggle_mode_button" then
    toggle_tool_mode_button(action, event)
  elseif action.action == "toggle_overlay" then
    toggle_overlay(action, event)
  elseif action.action == "remove_station" then
    remove_station_from_list(action, event)
  elseif action.action == "reload_grp" then
    reload_group(action, event)
  elseif action.action == "delgrp" then
    delete_group(action, event)
  elseif action.action == "clear" then
    clear_selected(action, event)
  end
end

script.on_event(defines.events.on_player_selected_area, on_player_selected_area)
script.on_event(defines.events.on_player_alt_selected_area, on_player_alt_selected_area)
script.on_event(defines.events.on_player_reverse_selected_area, on_player_reverse_selected_area)
-- script.on_event(defines.events.on_player_alt_reverse_selected_area, on_player_alt_reverse_selected_area)

return {
  open_gui = open_gui,
  update_gui = update_gui,
  close_gui = close_gui,
  destroy_gui = destroy_gui,
  create_gui = create_gui,
  handle_action = handle_action,
  toggle_groups_gui = toggle_groups_gui,
}
