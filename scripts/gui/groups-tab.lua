local flib_table = require("__flib__.table")
local flib_gui   = require("__flib__.gui")
-- local gui         = require("__virtm__.scripts.flib-gui")
local gui_utils  = require("__virtm__.scripts.gui.utils")
local match      = require("__virtm__.scripts.match")
local constants  = require("__virtm__.scripts.constants")
local backend    = require("__virtm__.scripts.backend")
local groups     = require("__virtm__.scripts.gui.groups")
local flib_box   = require("__flib__.bounding-box")
local searchbar    = require("__virtm__.scripts.gui.searchbar")

local groups_tab = {}

local function refresh(gui_data, event)
  script.raise_event(constants.refresh_event, {
    player_index = gui_data.player.index,
  })
end

---@param gui_data GuiData
---@param scroll_pane LuaGuiElement
---@param group_list table<uint,string>
local function update_group_list(gui_data, scroll_pane, group_list)
  local gui_state = storage.settings[gui_data.player.index]
  local surface = gui_state.surface or "All"
  local children = scroll_pane.children
  local width = constants.gui.groups_tab
  local style = constants.list_box_button_style
  local table_index = 0
  for _, set_name in pairs(group_list) do
    table_index = table_index + 1
    --set initial selection
    if gui_state.selected_group_set == set_name then
      style = constants.list_box_button_style_selected
    else
      style = constants.list_box_button_style
    end
    gui_data.gui.groups_warning.visible = false
    -- left side
    local row = children[table_index]
    local refs = {}
    if not row then
      local gui_content = {
        type = "button",
        style = constants.list_box_button_style,
        handler = { [defines.events.on_gui_click] = groups_tab.select_group },
        -- style_mods = { size = width.icon },
        -- tooltip = { "vtm.groups-tab-select-group_set" },
      }
      refs, row = flib_gui.add(scroll_pane, gui_content)
    end
    -- insert data left
    if table_size(refs) == 0 then
      refs = gui_utils.recreate_gui_refs(row)
    end
    row.tags = flib_table.shallow_merge({ row.tags, { group_set = set_name } })
    row.caption = set_name
  end -- end of for loop
  gui_data.gui.groups.badge_text = table_index or 0
  if table_index > 0 then
    gui_data.gui.groups_warning.visible = false
  else
    gui_data.gui.groups_warning.visible = true
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

local function member_row_contents()
  local width = constants.gui.groups_tab

  return  {
    type = "frame",
    style = "vtm_list_box_row_frame",
    style_mods = { horizontally_stretchable = true, height = 36, left_padding = 8, right_padding = 8 },
    {
      type = "label",
      name = "member_name",
      style = "vtm_clickable_semibold_label",
      style_mods = {
        width = width.member_name,
      },
      tooltip = { "gui-train.open-in-map" },
      handler = { [defines.events.on_gui_click] = groups_tab.show_station },
    },
    {
      type = "empty-widget",
      style = "flib_horizontal_pusher",
      ignored_by_interaction = true
    },
    gui_utils.slot_table(width, nil, "member_stock"),
  }

end

---@param gui_data GuiData
---@param scroll_pane LuaGuiElement
---@param group_list table<uint,GroupData>
local function update_gui_group_detail_view(gui_data, scroll_pane, group_list)
  local gui_state = storage.settings[gui_data.player.index]
  local surface = gui_state.surface or "All"
  local children = scroll_pane.children
  local width = constants.gui.groups_tab
  local table_index = 0
  local old_child = ""
  for _, group_data in pairs(group_list) do
    table_index = table_index + 1

    local row = children[table_index]
    local refs = {}
    if not row then
      local gui_contents = {
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
              { type = "label", style = "vtm_minimap_label", name = "minimap_label" },
              {
                type = "button",
                style = "vtm_minimap_button",
                name = "minimap_button",
                handler = { [defines.events.on_gui_click] = groups_tab.show_station }
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
              handler = { [defines.events.on_gui_click] = groups_tab.show_station }
            },
            {
              type = "empty-widget",
              style = "flib_horizontal_pusher",
              ignored_by_interaction = true
            },
            gui_utils.slot_table(width, nil, "member_stock"),
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
              handler = { [defines.events.on_gui_click] = groups_tab.open_group_edit },
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
      }
      refs, row = flib_gui.add(scroll_pane, gui_contents)
    end
    old_child = row.name
    if table_size(refs) == 0 then
      refs = gui_utils.recreate_gui_refs(row)
    end

    -- group center
    local position = flib_box.center(group_data.area)
    local zoom, max = gui_utils.get_zoom_from_area(group_data.area)
    if not group_data.main_station.stock_tick or (group_data.main_station.stock_tick and group_data.main_station.stock_tick < game.tick - 60) then
      local stock_data, is_circuit_limit = backend.read_station_network(group_data.main_station)
      group_data.main_station.stock = stock_data
      group_data.main_station.stock_tick = game.tick
    end
    local tooltip
    gui_utils.merge_slot_tables(group_data.main_station.stock, group_data.main_station.registered_stock)
    flib_table.sort(group_data.main_station.stock, function(a, b) return a.count < b.count end)
    tooltip = create_stock_tooltip(group_data.main_station.stock)
    -- insert data
    row.name = "detail_frame#" .. group_data.group_id
    refs.minimap.position = position
    refs.minimap.zoom = zoom or 1
    refs.minimap.surface_index = group_data.main_station.station.surface_index
    -- refs.minimap_label.caption = "Zoom " .. string.format("%2f", zoom) .. " - Max " .. max
    refs.minimap_button.tags = flib_table.shallow_merge({ refs.minimap_button.tags, { station_id = group_data.main_station.station.unit_number } })
    refs.main_station.caption = group_data.main_station.station.backer_name
    refs.main_station.tooltip = tooltip
    refs.main_station.tags = flib_table.shallow_merge({ refs.main_station.tags, { station_id = group_data.main_station.station.unit_number } })
    refs.editgrp_button.tags = flib_table.shallow_merge({ refs.editgrp_button.tags, { group_id = group_data.group_id } })

    gui_utils.slot_table_update(row.left_side.main_station_frame.member_stock_table, group_data.main_station.stock, searchbar.apply_filter)
    local scroll_pane_member = row.list_frame.scroll_pane_member or {}
    local member_children = scroll_pane_member.children or {}
    local member_index = 0


    for _, station_data in pairs(group_data.members) do
      member_index = member_index + 1
      local member = member_children[member_index]
      refs = {}
      if not member then
        local gui_contents = member_row_contents()
        refs, member = flib_gui.add(scroll_pane_member, gui_contents)
      end
      if not station_data.stock_tick or (station_data.stock_tick and station_data.stock_tick < game.tick - 60) then
        local stock_data, is_circuit_limit = backend.read_station_network(station_data)
        station_data.stock = stock_data
        station_data.stock_tick = game.tick
      end
      local tooltip
      gui_utils.merge_slot_tables(station_data.stock, station_data.registered_stock)
      flib_table.sort(station_data.stock, function(a, b) return a.count < b.count end)
      if table_size(station_data.stock) > 2 then
        tooltip = create_stock_tooltip(station_data.stock)
      end
      if table_size(refs) == 0 then
        refs = gui_utils.recreate_gui_refs(member)
      end
      refs.member_name.caption = station_data.station.backer_name
      refs.member_name.tooltip = tooltip or { "gui-train.open-in-map" }
      refs.member_name.tags = flib_table.shallow_merge({ refs.member_name.tags, { station_id = station_data.station.unit_number } })
      member.member_stock_table.style.left_padding = 0
      gui_utils.slot_table_update(member.member_stock_table, station_data.stock, searchbar.apply_filter)
    end
    --add resource tags
    for _, tag_data in pairs(group_data.resource_tags or {}) do
      member_index = member_index + 1
      local tag = member_children[member_index]
      refs = {}
      if not tag then
        local gui_contents = member_row_contents()        
        refs, tag = flib_gui.add(scroll_pane_member, gui_contents)
      end
      if table_size(refs) == 0 then
        refs = gui_utils.recreate_gui_refs(tag)
      end
      refs.member_name.caption = tag_data.text
      refs.member_name.tooltip = { "gui-train.open-in-map" }
      refs.member_name.tags = flib_table.shallow_merge({ refs.member_name.tags, { position = tag_data.position, surface_name = tag_data.surface.name } })
      tag.member_stock_table.style.left_padding = 0

      -- send nothing to clear old entries
      gui_utils.slot_table_update(tag.member_stock_table, {}, searchbar.apply_filter)
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
      flib_table.insert(group_list, set_member)
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
    flib_table.insert(del_set, set_name)
  end
  return group_data
end
---update the groups tab, optional preselect a group
function groups_tab.update_tab(gui_data, event)
  local player = gui_data.player
  local surface = storage.settings[player.index].surface or "All"

  local filters = {
    search_field = gui_data.gui.search_field.text:lower(),
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
      flib_table.insert(group_set_list, set_name)
      if not storage.settings[player.index].selected_group_set then
        storage.settings[player.index].selected_group_set = set_name
      end
      -- select entries for detail view
      if storage.settings[player.index].selected_group_set == set_name then
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
    storage.settings[player.index].selected_group_set = set_name
    local set = storage.group_set[set_name]
    set_members_for_display(set, player.force_index, group_list)
  end

  --sorting by name
  flib_table.sort(group_set_list, function(a, b) return a < b end)

  local scroll_left = gui_data.gui.scroll_pane_left or {}
  local scroll_right = gui_data.gui.scroll_pane_right or {}

  --left side
  update_group_list(gui_data, scroll_left, group_set_list)

  --right side
  update_gui_group_detail_view(gui_data, scroll_right, group_list)
end

function groups_tab.build_tab()
  local width = constants.gui.groups_tab
  return {
    tab = {
      type = "tab",
      name = "groups",
      caption = { "vtm.tab-groups" },
    },
    content = {
      type = "frame",
      style = "vtm_main_content_frame",
      direction = "vertical",
      name = "groups_content_frame",
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
              type = "button",
              style = "tool_button", --"frame_button",
              name = "new_group",
              caption = { "vtm.table-header-open_group_edit" },
              style_mods = { height = 24, },
              handler = { groups_tab.open_group_edit },
            },
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
            name = "scroll_pane_right",
            vertical_scroll_policy = "always",
            horizontal_scroll_policy = "never",
          },
        },
      },
      {
        type = "frame",
        direction = "horizontal",
        style = "negative_subheader_frame",
        name = "groups_warning",
        visible = true,
        {
          type = "flow",
          style = "compact_horizontal_flow",
          style_mods = { horizontally_stretchable = true },
          {
            type = "label",
            style = "bold_label",
            caption = { "", "[img=warning-white] ", { "vtm.no-groups" } },
            name = "groups_warning_label",
          },
        },
      },
    },
  }
end

--- @param gui_data GuiData
--- @param event EventData|EventData.on_gui_click
function groups_tab.select_group(gui_data, event)
  local set_name
  if event.element.tags and event.element.tags.group_set then
    set_name = event.element.tags.group_set --[[@as string]]
  else
    return
  end

  local player = gui_data.player
  if not set_name or not storage.group_set[set_name] then return end
  storage.settings[player.index].selected_group_set = set_name
  -- update_tab(action.gui_id)
  refresh(gui_data, event)
end

--- @param gui_data GuiData
--- @param event EventData|EventData.on_gui_click
function groups_tab.open_group_edit(gui_data, event)
  if not event.element.name == "new_group" and
      not event.element.name == "editgrp_button" then
    return
  end
  groups.open_gui(gui_data, event)
end

--- @param gui_data GuiData
--- @param event EventData|EventData.on_gui_click
function groups_tab.show_station(gui_data, event)
  gui_utils.show_station(gui_data, event)
end

flib_gui.add_handlers(groups_tab, function(event, handler)
  local gui_id = gui_utils.get_gui_id(event.player_index)
  ---@type GuiData
  local gui_data = storage.guis[gui_id]
  if gui_data then
    handler(gui_data, event)
  end
end, "groups_tab")


return groups_tab
