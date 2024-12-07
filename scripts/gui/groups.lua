-- groups.lua station groups
local flib_table = require("__flib__.table")
local flib_gui   = require("__flib__.gui")
local gui_utils  = require("__virtm__.scripts.gui.utils")
local util       = require("__core__.lualib.util")
local constants  = require("__virtm__.scripts.constants")
local backend    = require("__virtm__.scripts.backend")
local flib_box   = require("__flib__.bounding-box")

local groups     = {}

-- config sprite: side_menu_menu_icon
-- search sprite: search_white
-- refresh sprite: refresh_white
local function header(gui_id)
  return {
    type = "flow",
    drag_target = "groups_window",
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
        sprite = "utility/close",
        mouse_button_filter = { "left" },
        tooltip = { "gui.close" },
        handler = { [defines.events.on_gui_click] = groups.close_gui },
      }
    }
  }
end

local function dialog_buttons(gui_id)
  return {
    type = "flow",
    style = "dialog_buttons_horizontal_flow",
    children = {
      {
        type = "button",
        name = "clear_button",
        style = "back_button",
        caption = { "gui.clear" },
        mouse_button_filter = { "left" },
        handler = { [defines.events.on_gui_click] = groups.clear_selected },
      },
      {
        type = "empty-widget",
        style = "flib_horizontal_pusher",
        ignored_by_interaction = true
      },
      {
        type = "button",
        style = "dialog_button",
        name = "select_button",
        mouse_button_filter = { "left", "right" },
        caption = { "gui-permissions-names.SelectArea" },
        tooltip = { "vtm.groups-select-area" },
        handler = { [defines.events.on_gui_click] = groups.select_area },
      },
      {
        type = "empty-widget",
        style = "flib_horizontal_pusher",
        ignored_by_interaction = true
      },
      {
        type = "button",
        style = "confirm_button",
        name = "save_button",
        caption = { "gui.save" },
        tooltip = { "vtm.groups-save-and-clear" },
        mouse_button_filter = { "left" },
        handler = { [defines.events.on_gui_click] = groups.save_groups },
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
      handler = { [defines.events.on_gui_click] = groups.toggle_overlay },
    },
    {
      type = "sprite-button",
      style = "tool_button",
      sprite = "utility/area_icon",
      name = "toggle_mode_button",
      mouse_button_filter = { "left" },
      tooltip = { "vtm.groups-toggle-additive-selection-tooltip" },
      enabled = true,
      handler = { [defines.events.on_gui_click] = groups.toggle_mode_button },
    },
    {
      type = "sprite-button",
      style = "tool_button",
      sprite = "utility/close_black",
      name = "remove_button",
      tooltip = { "vtm.groups-remove-station-tooltip" },
      mouse_button_filter = { "left" },
      enabled = false,
      handler = { [defines.events.on_gui_click] = groups.remove_station_from_list },
    },
    {
      type = "sprite-button",
      style = "tool_button",
      sprite = "utility/reset",
      name = "reload_grp_button",
      tooltip = { "vtm.groups-reload-grp-tooltip" },
      mouse_button_filter = { "left" },
      enabled = false,
      handler = { [defines.events.on_gui_click] = groups.reload_group },
    },
    {
      type = "sprite-button",
      style = "tool_button_red",
      sprite = "utility/trash",
      name = "delgrp_button",
      tooltip = { "vtm.groups-delete-group-tooltip" },
      mouse_button_filter = { "left" },
      enabled = false,
      handler = { [defines.events.on_gui_click] = groups.delete_group },
    },
  }
  return content
end

local function gui_content(gui_id)
  local width = constants.gui.groups
  return {
    {
      type = "frame",
      direction = "vertical",
      name = "groups_window",
      style_mods = { minimal_width = width.window_min_width },
      handler = { [defines.events.on_gui_closed] = groups.on_window_closed },
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
            name = "top_buttons",
            style_mods = { horizontally_stretchable = true, horizontal_align = "right" },
            children = build_top_buttons(gui_id),
          },
          gui_utils.default_list_box(
            "top_list",
            nil,
            width.top_rows,
            "list_box_under_subheader",
            { [defines.events.on_gui_selection_state_changed] = groups.on_gui_elem_changed }),
          {
            type = "line",
            direction = "horizontal",
          },
          {
            type = "frame",
            style = "subheader_frame",
            direction = "horizontal",
            name = "bottom_header",
            style_mods = { horizontally_stretchable = true },
          },
          gui_utils.default_list_box(
            "bottom_list",
            nil,
            width.bottom_rows,
            "list_box_under_subheader",
            { [defines.events.on_gui_selection_state_changed] = groups.on_gui_elem_changed }),
        },
        dialog_buttons(gui_id),
      }
    }
  }
end

--- @param gui_data GuiData
--- @param event? EventData|EventData.on_gui_click
function groups.create_gui(gui_data, event)
  local player = gui_data.player
  if storage.groups[player.index] == nil then
    storage.groups[player.index] = {}
  end
  local ui = gui_content(gui_data.gui_id)
  local refs, window = flib_gui.add(player.gui.screen, ui)
  window.visible = false
  window.location = { 10, 150 }
  gui_data.group_gui = refs
  gui_data.state_groups = "closed"
end

local function split_stations(stations)
  ---@type table<uint,LuaEntity>
  local provider = {}
  ---@type table<uint,LuaEntity>
  local requester = {}
  for _, station in pairs(stations or {}) do
    if storage.stations[station.unit_number].type == "P" then
      flib_table.insert(provider, station)
    elseif storage.stations[station.unit_number].type == "R" then
      flib_table.insert(requester, station)
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
--- @param gui_data GuiData
local function clear_selected_data(gui_data)
  local group_gui = gui_data.group_gui
  if not group_gui then return end
  local top_buttons = group_gui.top_buttons
  local top_list = group_gui.top_list
  local bottom_list = group_gui.bottom_list
  -- actual group in editing
  local edit = storage.settings[gui_data.player.index].group_edit
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
  if not storage.group_tags or not player then return end
  local force = player.force
  if not storage.group_tags[force.index] then return end
  -- local surface = player.surface.name
  -- only one surface, and one user per force can show tags, to keep it simple
  for _, tag in pairs(storage.group_tags[force.index]) do
    if tag.valid then
      tag.destroy()
    end
  end
  storage.group_tags[force.index] = {}
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
    flib_table.insert(storage.group_tags[force.index], tag)
  end
  return tag
end

local function create_group_tags(gui_id)
  local vgui = storage.guis[gui_id]
  local player = vgui.player
  local force = player.force --[[@as LuaForce]]
  local surface = player.surface.name

  if not storage.group_tags then
    storage.group_tags = {}
  end
  if not storage.group_tags[force.index] then
    storage.group_tags[force.index] = {}
  end

  for group_id, group in pairs(storage.groups[force.index]) do
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
---@return LuaRenderObject
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
  local vgui = storage.guis[gui_id]
  local player = vgui.player
  local surface = player.surface.name
  for _, group in pairs(storage.groups[player.force_index]) do
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

local function remove_overlay(player)
  -- FIXME this will clear all overlays of all players, maybe there is a better solution to this
  rendering.clear(script.mod_name)
end

---Toggle overlay button
--- @param gui_data GuiData
--- @param event EventData|EventData.on_gui_click
function groups.toggle_overlay(gui_data, event)
  local edit = storage.settings[event.player_index].group_edit
  if edit and edit.show_overlay then
    event.element.style = "tool_button"
    edit.show_overlay = false
    remove_overlay(gui_data.player)
    remove_group_tags(gui_data.player)
  else
    event.element.style = "flib_selected_tool_button"
    edit.show_overlay = true
    show_overlay(gui_data.gui_id)
    create_group_tags(gui_data.gui_id)
  end
end

--- @param gui_data GuiData
--- @param event? EventData|EventData.on_gui_click
function groups.update_gui(gui_data, event)
  local surface = storage.settings[gui_data.player.index].surface or "All"
  local top_buttons = gui_data.group_gui.top_buttons
  local edit = storage.settings[gui_data.player.index].group_edit

  local top_names = {}
  local bottom_names = {}
  local top_list = gui_data.group_gui.top_list
  local bottom_list = gui_data.group_gui.bottom_list
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
    if storage.groups[station.force_index][station.unit_number] then
      name = name .. constants.group_exist_suffix
    end
    flib_table.insert(top_names, name)
  end
  for _, station in pairs(requester) do
    bottom_index = bottom_index + 1
    flib_table.insert(bottom_names, station.backer_name)
  end
  for _, tag in pairs(tag_list or {}) do
    bottom_index = bottom_index + 1
    flib_table.insert(bottom_names, tag.text)
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

--- @param gui_data GuiData
--- @param group_id uint
local function update_gui_from_group(gui_data, group_id)
  local edit = storage.settings[gui_data.player.index].group_edit

  if group_id then
    local stations = {}
    local group_data = backend.read_group(group_id)
    if group_data then
      clear_selected_data(gui_data)
      edit.selected_group_id = group_data.group_id
      edit.selected_stations = {}
      edit.selected_tags = {}
      flib_table.insert(stations, group_data.main_station.station)
      edit.group_area = group_data.area
      for _, station_data in pairs(group_data.members) do
        if station_data.station.valid then
          flib_table.insert(stations, station_data.station)
        end
      end
      merge_station_list(edit.selected_stations, stations)
      merge_tag_list(edit.selected_tags, group_data.resource_tags)
    end
    groups.update_gui(gui_data)
  end
end

---Make groups gui visible, tags can contain group_id or clear argument to remove all content
--- @param gui_data GuiData
--- @param event EventData|EventData.on_gui_click|EventData.on_lua_shortcut
function groups.open_gui(gui_data, event)
  gui_data.group_gui.groups_window.visible = true
  gui_data.state_groups = "open"
  if event.element and event.element.tags and event.element.tags.group_id then
    group_id = event.element.tags.group_id --[[@as string]]
    update_gui_from_group(gui_data, event.element.tags.group_id --[[@as uint]])
    return
  elseif event.element and event.element.tags and event.element.tags.clear then
    clear_selected_data(gui_data)
  elseif event.prototype_name ~= "vtm-groups-shortcut" then
    return
  end
  groups.update_gui(gui_data, event)
end

---Create set or add station
---@param name string
---@param group_id uint
local function register_group_set(name, group_id)
  if not name or not group_id then return end
  if not storage.group_set[name] then
    storage.group_set[name] = {}
  end
  for _, value in pairs(storage.group_set[name]) do
    if value == group_id then
      return
    end
  end
  flib_table.insert(storage.group_set[name], group_id)
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
    local vgui = storage.guis[gui_id]
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
--- @param gui_data GuiData
--- @param event EventData|EventData.on_gui_click
function groups.save_groups(gui_data, event)
  local edit = storage.settings[event.player_index].group_edit
  -- validate data
  if not validate_group_data(edit) then
    gui_data.player.create_local_flying_text({
      text = { "vtm.groups-error-saving-group" },
      create_at_cursor = true,
    })
    groups.update_gui(gui_data, event)
    return false
  end

  local tag_list = edit.selected_tags or {}
  local provider, requester = split_stations(edit.selected_stations)
  if #provider == 0 or (#requester == 0 and table_size(tag_list) == 0) then
    gui_data.player.create_local_flying_text({
      text = { "vtm.groups-error-saving-group" },
      create_at_cursor = true,
    })
    return false
  end
  -- TODO maybe check for surface mismatch
  local group_members = {}

  for _, r_station in pairs(requester) do
    flib_table.insert(group_members, backend.get_or_create_station_data(r_station))
  end
  for _, p_station in pairs(provider) do
    ---@type GroupData
    local group_data = {
      created = game.tick,
      group_id = p_station.unit_number,
      members = group_members,
      main_station = backend.get_or_create_station_data(p_station),
      surface = p_station.surface.name,
      area = edit.group_area,
      resource_tags = tag_list,
      zoom = gui_utils.get_zoom_from_area(edit.group_area)
    }
    storage.groups[p_station.force_index][p_station.unit_number] = group_data
    register_group_set(p_station.backer_name, p_station.unit_number)
    gui_data.player.print({ "vtm.groups-saved", p_station.unit_number })
    add_group_overlay(gui_data.gui_id, group_data, edit.show_overlay)
  end
  clear_selected_data(gui_data)
  groups.update_gui(gui_data, event)
  return true
end

local function give_selector(player)
  if player.clear_cursor() then
    player.cursor_stack.set_stack({ name = "vtm-station-group-selector" })
    player.cursor_stack_temporary = true
  end
end

---Clear edit window
--- @param gui_data GuiData
--- @param event EventData|EventData.on_gui_click
function groups.clear_selected(gui_data, event)
  clear_selected_data(gui_data)
  groups.update_gui(gui_data, event)
end

--- @param gui_data GuiData
--- @param event EventData.on_gui_elem_changed
function groups.on_gui_elem_changed(gui_data, event)
  local group_gui   = gui_data.group_gui
  ---@type LuaGuiElement
  local top_buttons = group_gui.top_buttons
  ---@type LuaGuiElement
  local top_list    = group_gui.top_list
  ---@type LuaGuiElement
  local bottom_list = group_gui.bottom_list

  if event.element.name == "top_list" then
    bottom_list.selected_index = 0
    -- check for existing group
    local str = top_list.get_item(event.element.selected_index) --[[@as string]]
    -- enable delgrp_button
    if gui_utils.string_ends_with(str, constants.group_exist_suffix) then
      top_buttons.delgrp_button.enabled = true
      gui_utils.set_style(top_buttons.delgrp_button, constants.button_style_red)
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
--- @param gui_data GuiData
--- @param event EventData|EventData.on_gui_click
function groups.toggle_mode_button(gui_data, event)
  local edit = storage.settings[event.player_index].group_edit
  if edit and edit.add_to_selection then
    event.element.style = "tool_button"
    edit.add_to_selection = false
  else
    event.element.style = "flib_selected_tool_button"
    edit.add_to_selection = true
  end
end

--- @param gui_data GuiData
--- @param event EventData|EventData.on_gui_click
function groups.close_gui(gui_data, event)
  local edit = storage.settings[gui_data.player.index].group_edit or {}
  local refs = gui_data.group_gui
  refs.groups_window.visible = false
  gui_data.state_groups = "closed"
  edit.show_overlay = false
  remove_overlay(gui_data.player)
  remove_group_tags(gui_data.player)
  gui_data.player.clear_cursor()
end

function groups.destroy_gui(gui_data, event)
  groups.close_gui(gui_data, event)
  clear_selected_data(gui_data)
  gui_data.group_gui.groups_window.destroy()
  gui_data.group_gui = nil
end

--- @param gui_data GuiData
--- @param event EventData|EventData.on_gui_click
function groups.remove_station_from_list(gui_data, event)
  local edit                = storage.settings[event.player_index].group_edit
  local group_gui           = gui_data.group_gui
  local top_buttons         = group_gui.top_buttons
  local top_list            = group_gui.top_list
  local bottom_list         = group_gui.bottom_list
  local provider, requester = split_stations(edit.selected_stations)
  local station

  if top_list.selected_index > 0 then
    local name = top_list.items[top_list.selected_index] --[[@as string]]
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
  -- update_gui(action.gui_id, edit.selected_stations)
  groups.update_gui(gui_data, event)
end

local function remove_group_from_set(station)
  if not station.valid then return end
  local set = storage.group_set[station.backer_name]
  if not set then return end
  local remove
  for key, group_id in pairs(set) do
    if group_id == station.unit_number then
      remove = key
    end
  end
  flib_table.remove(set, remove)
  if table_size(set) == 0 then
    storage.group_set[station.backer_name] = nil
  end
end

--- @param gui_data GuiData
--- @param event EventData|EventData.on_gui_click
function groups.delete_group(gui_data, event)
  --two steps
  local edit        = storage.settings[event.player_index].group_edit
  local player      = game.get_player(event.player_index)
  local group_gui   = gui_data.group_gui
  local top_buttons = group_gui.top_buttons
  local button      = top_buttons.delgrp_button
  local top_list    = group_gui.top_list
  local style_red   = constants.button_style_red
  local style_green = constants.button_style_green
  local p_station

  local group_id    = edit.selected_group_id

  if not group_id and top_list.selected_index > 0 then
    for _, station in pairs(edit.selected_stations) do
      local name = top_list.items[top_list.selected_index] --[[@as string]]
      if util.string_starts_with(name, station.backer_name) then
        p_station = station
        break
      end
    end
  else
    p_station = storage.stations[group_id] and storage.stations[group_id].station
  end

  if not button or not button.enabled or not p_station or not player then return end

  if button.style.name == style_green then
    gui_utils.set_style(button, style_red)
    -- delete set entry
    remove_group_from_set(p_station)
    --delete the group
    storage.groups[p_station.force_index][p_station.unit_number] = nil
    clear_selected_data(gui_data)
    -- update_gui(action.gui_id, {})
    groups.update_gui(gui_data, event)

    player.print({ "vtm.groups-group-deleted", p_station.unit_number })
  elseif button.style.name == style_red then
    button.style = style_green
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
      flib_table.insert(stations, entity)
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
    local gui_id = gui_utils.get_gui_id(player.index)
    local gui_data = storage.guis[gui_id]
    --TODO no elevator
    if selected_stations and gui_id then
      local edit = storage.settings[player.index].group_edit
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
        if remove then -- is the selected station in old selection, then remove
          edit.selected_stations[remove] = nil
        end
      end
      -- update_gui(gui_id, edit.selected_stations)
      groups.update_gui(gui_data, event)
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
  local gui_id = gui_utils.get_gui_id(player.index)
  local gui_data = storage.guis[gui_id]
  if next(selected_tags) then
    filter_own_tags(selected_tags)
  end
  if next(selected_tags) and gui_id then
    local edit = storage.settings[player.index].group_edit
    player.clear_cursor()
    if not edit.add_to_selection or edit.selected_tags == nil then
      edit.selected_tags = {}
    end
    -- merge and store in global
    merge_tag_list(edit.selected_tags, selected_tags)
    groups.update_gui(gui_data, event)
  end
end

---handle station selection
---@param event EventData.on_player_selected_area
local function on_station_selection(event)
  local player = game.get_player(event.player_index)
  if player and event.entities then
    local selected_stations = extract_train_stops(event)
    local gui_id = gui_utils.get_gui_id(player.index)
    local gui_data = storage.guis[gui_id]
    if selected_stations and gui_id then
      local edit = storage.settings[player.index].group_edit
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
      -- update_gui(gui_id, edit.selected_stations)
      groups.update_gui(gui_data, event)
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

--- @param gui_data GuiData
--- @param event EventData|EventData.on_gui_click
function groups.reload_group(gui_data, event)
  local edit = storage.settings[event.player_index].group_edit
  update_gui_from_group(gui_data, edit.selected_group_id)
end

-- ---React on user input
-- ---@param action table
-- ---@param event table
-- local function handle_action(action, event)
--   if action.action == "close-window" then
--     -- groups.close_gui(gui_data, event)
--   elseif action.action == "select_element" then
--     -- on_gui_elem_changed(event)
--   elseif action.action == "select_area" then
--     -- local player = game.get_player(event.player_index)
--     -- if not player then return end
--     -- give_selector(player)
--   elseif action.action == "save" then
--     -- save_groups(action, event)
--     -- todo give better feedback on error
--   elseif action.action == "toggle_mode_button" then
--     -- toggle_tool_mode_button(action, event)
--   elseif action.action == "toggle_overlay" then
--     -- toggle_overlay(action, event)
--   elseif action.action == "remove_station" then
--     -- remove_station_from_list(action, event)
--   elseif action.action == "reload_grp" then
--     -- reload_group(action, event)
--   elseif action.action == "delgrp" then
--     -- delete_group(action, event)
--   elseif action.action == "clear" then
--     -- clear_selected(action, event)
--   end
-- end

--- @param gui_data GuiData
--- @param event EventData|EventData.on_gui_click
function groups.select_area(gui_data, event)
  give_selector(gui_data.player)
end

--- @param gui_data GuiData
--- @param event EventData|EventData.on_gui_click
function groups.toggle_groups_gui(gui_data, event)
  if gui_data.state_groups and
      gui_data.state_groups == "closed" or
      gui_data.state_groups == nil then
    groups.open_gui(gui_data, event)
    give_selector(gui_data.player)
  else
    groups.close_gui(gui_data, event)
  end
end

-- script.on_event(defines.events.on_player_alt_reverse_selected_area, on_player_alt_reverse_selected_area)
--- @param event EventData|EventData.on_lua_shortcut
function groups.on_lua_shortcut(event)
  if event.prototype_name == "vtm-groups-shortcut" then
    local gui_data = storage.guis[gui_utils.get_gui_id(event.player_index)]
    groups.toggle_groups_gui(gui_data, event)
  end
end

--- @param event EventData|EventData.CustomInputEvent
function groups.open_or_close_gui(event)
  if event.input_name == "vtm-groups-key" then
    local gui_data = storage.guis[gui_utils.get_gui_id(event.player_index)]
    groups.toggle_groups_gui(gui_data, event)
  end
end

--- @param gui_data GuiData
--- @param event EventData|EventData.on_gui_click
function groups.on_window_closed(gui_data, event)
  if gui_data.pinned then
    return
  end
  groups.close_gui(gui_data, event)
end

flib_gui.add_handlers(groups, function(event, handler)
  local gui_id = gui_utils.get_gui_id(event.player_index)
  ---@type GuiData
  local gui_data = storage.guis[gui_id]
  if gui_data then
    handler(gui_data, event)
  end
end, "groups")

groups.events = {
  ["vtm-groups-key"] = groups.open_or_close_gui,
  [defines.events.on_lua_shortcut] = groups.on_lua_shortcut,
  [defines.events.on_player_selected_area] = on_player_selected_area,
  [defines.events.on_player_alt_selected_area] = on_player_alt_selected_area,
  [defines.events.on_player_reverse_selected_area] = on_player_reverse_selected_area,
}

return groups
