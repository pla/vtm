local table     = require("__flib__.table")
-- local gui         = require("__flib__.gui")
local gui         = require("__virtm__.scripts.flib-gui")
local gui_util  = require("__virtm__.scripts.gui.utils")
local match     = require("__virtm__.scripts.match")
local constants = require("__virtm__.scripts.constants")
local vtm_logic = require("__virtm__.scripts.vtm_logic")
local groups    = require("__virtm__.scripts.gui.groups")
local flib_box  = require("__flib__.bounding-box")

---@param gui_id uint
---@param scroll_pane LuaGuiElement
---@param group_list table<uint,string>
local function update_group_list(gui_id, scroll_pane, group_list)
  local vsettings = storage.settings[storage.guis[gui_id].player.index]
  local vtm_gui = storage.guis[gui_id]
  local surface = vsettings.surface or "All"
  local children = scroll_pane.children
  local width = constants.gui.groups_tab
  local style = constants.list_box_button_style
  local table_index = 0
  for _, set_name in pairs(group_list) do
    table_index = table_index + 1
    --set initial selection
    if vsettings.selected_group_set == set_name then
      style = constants.list_box_button_style_selected
    else
      style = constants.list_box_button_style
    end
    vtm_gui.gui.groups.warning.visible = false
    -- left side
    local row = children[table_index]
    if not row then
      row = gui.add(scroll_pane, {
        type = "button",
        style = constants.list_box_button_style,
        -- style_mods = { size = width.icon },
        -- tooltip = { "vtm.groups-tab-select-group_set" },
      })
    end
    -- insert data left
    gui.update(row,
      {
        -- name
        elem_mods = { caption = set_name, style = style },
        actions = {
          on_click = { type = "groups_tab", action = "show_detail", gui_id = gui_id, group_set = set_name },
        },
      })
  end -- end of for loop
  vtm_gui.gui.tabs.groups_tab.badge_text = table_index or 0
  if table_index > 0 then
    vtm_gui.gui.groups.warning.visible = false
  else
    vtm_gui.gui.groups.warning.visible = true
  end

  for child_index = table_index + 1, #children do
    children[child_index].destroy()
  end
end

---Validate group members and tags
---@param group_data GroupData
local function validate_group(group_data)
  -- main_station should be validated before this function call
  -- validate members
  for key, member in pairs(group_data.members) do
    if not member.station.valid then
      group_data.members[key] = nil
    end
  end

  for key, tag in pairs(group_data.resource_tags or {}) do
    if not tag.valid then
      group_data.resource_tags[key] = nil
    end
  end
end

--- create a tooltip with al item line, if more then 2 lines in the table
---@param stock_table SlotTableDef[]
---@return string?
local function create_stock_tooltip(stock_table)
  local tooltip
  tooltip = ""
  for _, item in pairs(stock_table) do
    tooltip = tooltip .. "[" .. item.type .. "=" .. item.name .. "] x " .. util.format_number(item.count, true) .. "\n"
  end
  if tooltip ~= "" then
    tooltip = string.sub(tooltip, 1, -2)
  end
  return tooltip
end

---@param gui_id uint
---@param scroll_pane LuaGuiElement
---@param group_list table<uint,GroupData>
local function update_gui_group_detail_view(gui_id, scroll_pane, group_list)
  local vsettings = storage.settings[storage.guis[gui_id].player.index]
  local vtm_gui = storage.guis[gui_id]
  local surface = vsettings.surface or "All"
  local children = scroll_pane.children
  local width = constants.gui.groups_tab
  local table_index = 0
  local old_child = ""
  for _, group_data in pairs(group_list) do
    table_index = table_index + 1

    local row = children[table_index]
    if not row then
      row = gui.add(scroll_pane, {
        -- group detail frame
        type = "frame",
        direction = "horizontal",
        style = "train_with_minimap_frame",
        -- style = "vtm_table_row_frame",
        style_mods = { horizontally_stretchable = true, vertically_stretchable = false, },
        {
          -- frame for minimap
          type = "flow",
          direction = "vertical",
          name = "left_side",
          style_mods = {
            horizontally_stretchable = false,
            vertically_stretchable = true,
            height = width.content_height,
            vertical_spacing = 12
          },
          {
            -- the minimap
            type = "frame",
            style = "deep_frame_in_shallow_frame",
            style_mods = { horizontal_align = "center", vertical_align = "center" },
            {
              type = "minimap",
              name = "minimap",
              size = width.map,
              { type = "label", style = "vtm_minimap_label" },
              {
                type = "button",
                style = "vtm_minimap_button",
              },
            },
          },
          {
            -- main station
            type = "frame",
            style = "vtm_deep_frame",
            name = "main_station_frame",
            style_mods = {
              height = 36,
              left_padding = 8,
              right_padding = 8,
            },
            {
              type = "label",
              style = "vtm_clickable_semibold_label",
              name = "main_station",
              style_mods = {
                width = width.main_station_name,
              },
              tooltip = { "gui-train.open-in-map" },
            },
            {
              type = "empty-widget",
              style = "flib_horizontal_pusher",
              ignored_by_interaction = true
            },
            gui_util.slot_table(width, nil, "member_stock"),
          }
        },
        {
          --listbox style display for group members
          type = "frame",
          style = "deep_frame_in_shallow_frame",
          name = "list_frame",
          direction = "vertical",
          style_mods = {
            horizontally_stretchable = true,
            minimal_height = width.content_height,
            maximal_height = width.content_height,
          },
          {
            -- table header
            type = "frame",
            style = "subheader_frame",
            name = "subheader_frame",
            direction = "horizontal",
            style_mods = { horizontally_stretchable = true },
            {
              type = "sprite-button",
              style = "tool_button",
              sprite = "utility/rename_icon",
              name = "editgrp_button",
              tooltip = { "vtm.groups-edit-group-tooltip" },
              mouse_button_filter = { "left" },
            },
            {
              type = "label",
              style = "subheader_caption_label",
              style_mods = { width = width.icon },
            },
          },
          {
            -- member scroll pane
            type = "scroll-pane",
            style = "vtm_list_box_scroll_pane",
            name = "scroll_pane_member",
            vertical_scroll_policy = "always",
            horizontal_scroll_policy = "never",
          },
        }
      })
    end
    old_child = row.name

    -- group center
    local position = flib_box.center(group_data.area)
    local zoom = gui_util.get_zoom_from_area(group_data.area)
    if not group_data.main_station.stock_tick or (group_data.main_station.stock_tick and group_data.main_station.stock_tick < game.tick - 60) then
      local stock_data, is_circuit_limit = vtm_logic.read_station_network(group_data.main_station)
      group_data.main_station.stock = stock_data
      group_data.main_station.stock_tick = game.tick
    end
    local tooltip
    gui_util.merge_slot_tables(group_data.main_station.stock, group_data.main_station.registered_stock)
    table.sort(group_data.main_station.stock, function(a, b) return a.count < b.count end)
    tooltip = create_stock_tooltip(group_data.main_station.stock)
    -- insert data
    gui.update(row,
      {
        --detail_frame
        name = "detail_frame#" .. group_data.group_id,
        {
          { -- minimap frame
            {
              -- minimap
              elem_mods = {
                position = position,
                zoom = zoom or 1,
                surface_index = group_data.main_station.station.surface_index
              },
              {}, -- label
              {
                  --button
                actions = {
                  on_click = {
                    type = "stations",
                    action = "position",
                    station_id = group_data.main_station.station.unit_number
                  },
                },
              },
            },
          },
          { -- main station frame
            {
              elem_mods = {
                caption = group_data.main_station.station.backer_name,
                tooltip = tooltip
              },
              actions = {
                on_click = {
                  type = "stations",
                  action = "position",
                  station_id = group_data.main_station.station.unit_number
                },
              },
            },
          },
        },
        {   --list_frame
          { --subheader_frame
            {
              -- edit button
              actions = {
                on_click = { type = "stations", action = "show_group_ui", group_id = group_data.group_id, gui_id = gui_id },
              },
            },
          },
        },
      })
    gui_util.slot_table_update(row.left_side.main_station_frame.member_stock_table, group_data.main_station.stock, gui_id,
      1)
    local scroll_pane_member = row.list_frame.scroll_pane_member or {}
    local member_children = scroll_pane_member.children or {}
    local member_index = 0


    for _, station_data in pairs(group_data.members) do
      member_index = member_index + 1
      local member = member_children[member_index]
      if not member then
        member = gui.add(scroll_pane_member, {
          type = "frame",
          style = "vtm_list_box_row_frame",
          style_mods = { horizontally_stretchable = true, height = 36, left_padding = 8, right_padding = 8 },
          {
            type = "label",
            style = "vtm_clickable_semibold_label",
            style_mods = {
              width = width.member_name,
            },
            tooltip = { "gui-train.open-in-map" },
          },
          {
            type = "empty-widget",
            style = "flib_horizontal_pusher",
            ignored_by_interaction = true
          },
          gui_util.slot_table(width, nil, "member_stock"),
        })
      end
      if not station_data.stock_tick or (station_data.stock_tick and station_data.stock_tick < game.tick - 60) then
        local stock_data, is_circuit_limit = vtm_logic.read_station_network(station_data)
        station_data.stock = stock_data
        station_data.stock_tick = game.tick
      end
      local tooltip
      gui_util.merge_slot_tables(station_data.stock, station_data.registered_stock)
      table.sort(station_data.stock, function(a, b) return a.count < b.count end)
      if table_size(station_data.stock) > 2 then
        tooltip = create_stock_tooltip(station_data.stock)
      end
      gui.update(member, { --flow
        {
          -- button
          elem_mods = {
            caption = station_data.station.backer_name,
            tooltip = tooltip or { "gui-train.open-in-map" },
          },
          actions = {
            on_click = { type = "stations", action = "position", station_id = station_data.station.unit_number },
          },
        },
        {
          -- slot table
          style_mods = {
            left_padding = 0,
          }
        },
      })
      gui_util.slot_table_update(member.member_stock_table, station_data.stock, gui_id, 1)
    end
    --add resource tags
    for _, tag_data in pairs(group_data.resource_tags or {}) do
      member_index = member_index + 1
      local tag = member_children[member_index]
      if not tag then
        tag = gui.add(scroll_pane_member, {
          type = "frame",
          style = "vtm_list_box_row_frame",
          style_mods = { horizontally_stretchable = true, height = 36, left_padding = 8, right_padding = 8 },
          {
            type = "label",
            style = "vtm_clickable_semibold_label",
            style_mods = {
              width = width.member_name,
            },
            tooltip = { "gui-train.open-in-map" },
          },
          {
            type = "empty-widget",
            style = "flib_horizontal_pusher",
            ignored_by_interaction = true
          },
          gui_util.slot_table(width, nil, "member_stock"),
        })
      end
      gui.update(tag, { --flow
        {
          -- button
          elem_mods = {
            caption = tag_data.text,
            tooltip = { "gui-train.open-in-map" },
          },
          actions = {
            on_click = {
              type = "stations",
              action = "position",
              position = tag_data.position,
              surface_name = tag_data.surface.name
            },
          },
        },
        {
          -- slot table
          style_mods = {
            left_padding = 0
          }
        },
      })
      -- send nothing to clear old entries
      gui_util.slot_table_update(tag.member_stock_table, {}, gui_id)
    end

    -- cleanup member scroll pane
    for child_index = member_index + 1, #member_children do
      member_children[child_index].destroy()
    end
  end

  if table_index > 0 and old_child ~= scroll_pane.children[1].name then
    scroll_pane.scroll_to_top()
  end
  for child_index = table_index + 1, #children do
    children[child_index].destroy()
  end
end

---selected group from set for tab display
---@param set table<uint>
---@param force_index uint
---@param group_list table<GroupData>
local function set_members_for_display(set, force_index, group_list)
  for _, group_id in pairs(set) do
    local set_member = storage.groups[force_index][group_id]
    if set_member and set_member.main_station and set_member.main_station.station.valid then
      validate_group(set_member) --check members and tags for validity
      table.insert(group_list, set_member)
    else
      -- delete invalid group
      storage.groups[force_index][group_id] = nil
      set[_] = nil
    end
  end
end

---get first valid group and cleanup group_set, if necessary mark set for deletion
---@param set_name string
---@param set table<uint,string>
---@param del_set table<uint,string>
---@param force_index uint
---@return GroupData
local function get_first_valid_set_member(set_name, set, del_set, force_index)
  local group_data
  if not storage.groups[force_index] or not storage.groups[force_index] then
    return group_data
  end
  for key, group_id in pairs(set) do
    group_data = storage.groups[force_index][group_id]
    if group_data and group_data.main_station and group_data.main_station.station.valid then
      break
    else
      storage.groups[force_index][group_id] = nil
      set[key] = nil
    end
  end
  if table_size(set) == 0 then
    table.insert(del_set, set_name)
  end
  return group_data
end
---update the groups tab, optional preselect a group
---@param gui_id uint
---@param group_id? uint
local function update_tab(gui_id, group_id)
  local vtm_gui = storage.guis[gui_id]
  local player = vtm_gui.player
  local vsettings = storage.settings[storage.guis[gui_id].player.index]
  local surface = vsettings.surface or "All"

  local filters = {
    search_field = vtm_gui.gui.filter.search_field.text:lower(),
  }
  ---@type table<uint, string>
  local group_set_list = {}
  local group_list = {}
  ---@type table<uint, string>
  local del_set = {}
  for set_name, set in pairs(storage.group_set) do
    ---@type GroupData
    local group_data = get_first_valid_set_member(set_name, set, del_set, player.force_index)
    if group_data and
        (surface == "All" or surface == group_data.surface) and
        match.filter_group_set(set_name, filters) and
        group_data.main_station and
        group_data.main_station.station.valid and
        group_data.main_station.force_index == player.force_index
    then
      table.insert(group_set_list, set_name)
      if not vsettings.selected_group_set then
        vsettings.selected_group_set = set_name
      end
      -- select entries for detail view
      if vsettings.selected_group_set == set_name then
        set_members_for_display(set, player.force_index, group_list)
      end
    end
  end
  -- remove invalid group sets
  for _, set_name in pairs(del_set) do
    storage.group_set[set_name] = nil
  end
  if table_size(group_list) == 0 and table_size(group_set_list) > 0 then
    --nothing selected, take first set in display
    local _, set_name = next(group_set_list)
    vsettings.selected_group_set = set_name
    local set = storage.group_set[set_name]
    set_members_for_display(set, player.force_index, group_list)
  end

  --sorting by name
  table.sort(group_set_list, function(a, b) return a < b end)

  local scroll_left = vtm_gui.gui.groups.scroll_pane_left or {}
  local scroll_right = vtm_gui.gui.groups.scroll_pane_right or {}
  -- TODO: ?switch compact view maybe

  --left side
  update_group_list(gui_id, scroll_left, group_set_list)

  --right side
  update_gui_group_detail_view(gui_id, scroll_right, group_list)
end


local function build_gui()
  local width = constants.gui.groups_tab
  return {
    tab = {
      type = "tab",
      caption = { "vtm.tab-groups" },
      ref = { "tabs", "groups_tab" },
      name = "groups",
      actions = {
        on_click = { type = "generic", action = "change_tab", tab = "groups" },
      },
    },
    content = {
      type = "frame",
      style = "vtm_main_content_frame",
      direction = "vertical",
      ref = { "groups", "content_frame" },
      {
        type = "flow",
        -- style = "",
        direction = "horizontal",
        style_mods = { horizontally_stretchable = true, padding = 0, horizontal_spacing = 8 },
        {
          type = "frame", -- left frame
          style = "deep_frame_in_shallow_frame",
          direction = "vertical",
          style_mods = { width = width.group_list },
          {
            -- table header
            type = "frame",
            style = "subheader_frame",
            direction = "horizontal",
            style_mods = { horizontally_stretchable = true },
            {
              type = "label",
              style = "subheader_caption_label",
              style_mods = { width = width.icon },
            },
            {
              type = "label",
              style = "subheader_caption_label",
              caption = { "vtm.table-header-name" },
              style_mods = { width = width.name },
            },
          },
          {
            -- left scroll pane
            type = "scroll-pane",
            style = "vtm_groups_list_box_scroll_pane",
            ref = { "groups", "scroll_pane_left" },
            name = "scroll_pane_left",
            vertical_scroll_policy = "always",
            horizontal_scroll_policy = "never",
            -- style_mods = { horizontally_stretchable = true, },
          },
        },
        {
          --right frame
          type = "frame",
          style = "deep_frame_in_shallow_frame",
          direction = "vertical",
          name = "detail_list",
          style_mods = { width = width.detail_list, },
          {
            -- table header
            type = "frame",
            style = "subheader_frame",
            direction = "horizontal",
            style_mods = { horizontally_stretchable = true },
            {
              type = "label",
              style = "subheader_caption_label",
              style_mods = { width = width.icon },
            },
            -- {
            --   type = "label",
            --   style = "subheader_caption_label",
            --   caption = { "vtm.table-header-name" },
            --   style_mods = { width = width.name },
            -- },
          },
          {
            -- right scroll pane
            type = "scroll-pane",
            style = "vtm_table_scroll_pane",
            ref = { "groups", "scroll_pane_right" },
            vertical_scroll_policy = "always",
            horizontal_scroll_policy = "never",
          },
        },
      },
      {
        type = "frame",
        direction = "horizontal",
        style = "negative_subheader_frame",
        ref = { "groups", "warning" },
        visible = true,
        {
          type = "flow",
          style = "compact_horizontal_flow",
          style_mods = { horizontally_stretchable = true },
          {
            type = "label",
            style = "bold_label",
            caption = { "", "[img=warning-white] ", { "vtm.no-groups" } },
            ref = { "groups", "warning_label" },
          },
        },
      },
    },
  }
end

---comment
---@param action GuiAction
---@param event EventData|any
local function select_group(action, event)
  local vtm_gui = storage.guis[action.gui_id]
  local player = vtm_gui.player
  local vsettings = storage.settings[player.index]
  local set_name = action.group_set
  if not set_name or not storage.group_set[set_name] then return end
  vsettings.selected_group_set = set_name
  update_tab(action.gui_id)
end

---comment
---@param action GuiAction
---@param event EventData|any
local function handle_action(action, event)
  if action.action == "show_detail" then
    if not action.group_set then return end
    select_group(action, event)
  elseif action.action == "position" then
  end
end

return {
  build_gui = build_gui,
  update_tab = update_tab,
  handle_action = handle_action
}
