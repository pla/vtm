local constants = require("scripts.constants")
local tables = require("__flib__.table")
local gui = require("__flib__.gui")
local gui_util = require("scripts.gui.util")
local match = require("scripts.match")
local vtm_logic = require("scripts.vtm_logic")

local function status_color(station)
  -- FIXME: actually do something
  return "green"
end

local function depot_limit(station_data)
  local limit = station_data.limit
  local inbound = station_data.inbound
  return inbound .. "/" .. limit
end

local function update_tab(gui_id)
  local vtm_gui = global.guis[gui_id]
  local stations = {}
  local depots_compact = {}
  local limit
  local table_index = 0
  local filters = {
    item = vtm_gui.gui.filter.item.elem_value,
    fluid = vtm_gui.gui.filter.fluid.elem_value,
    search_field = vtm_gui.gui.filter.search_field.text:lower(),
  }

  for _, station_data in pairs(global.stations) do
    if station_data.force_index == vtm_gui.player.force.index and
        (station_data.type == "D" or
            station_data.type == "F")
    then
      if station_data.station.valid then
        -- record present
        limit = station_data.station.trains_limit
        if limit == constants.MAX_LIMIT then
          limit = 1
        end
        if depots_compact[station_data.station.backer_name] then
          depots_compact[station_data.station.backer_name].limit =
          depots_compact[station_data.station.backer_name].limit + limit

          depots_compact[station_data.station.backer_name].inbound =
          depots_compact[station_data.station.backer_name].inbound +
              station_data.station.trains_count

        else
          -- new record
          depots_compact[station_data.station.backer_name] = {
            station = station_data.station,
            name = station_data.station.backer_name,
            type = station_data.type,
            inbound = station_data.station.trains_count,
            limit = limit,
          }
        end
      end
    end
  end

  local scroll_pane = vtm_gui.gui.depots.scroll_pane
  local children = scroll_pane.children
  local width = constants.gui.depots

  for _, station_data in pairs(depots_compact) do

    if station_data.station.valid then
      table_index = table_index + 1
      -- get or create gui row
      local row = children[table_index]
      local color = table_index % 2 == 0 and "dark" or "light"
      if not row then
        row = gui.add(scroll_pane, {
          type = "frame",
          direction = "horizontal",
          style = "vtm_table_row_frame",
          -- style = "vtm_table_row_frame_" .. color,
          {
            type = "label",
            style = "vtm_clickable_semibold_label",
            style_mods = { width = width.name },
            tooltip = "vtm.open_station_gui_tooltip",
          },
          {
            type = "flow",
            style = "flib_indicator_flow",
            style_mods = { horizontal_align = "left", width = width.status },
            { type = "sprite", style = "flib_indicator" },
            { type = "label", style = "vtm_semibold_label" },
          },
          {
            type = "label",
            style = "vtm_semibold_label",
            style_mods = { width = width.type },
          },
          {
            type = "empty-widget",
            style = "flib_horizontal_pusher",
            style_mods = { height = 20, },
          },
          gui_util.slot_table(width, "light", "stock"),
        })
      end
      -- insert data

      gui.update(row, {
        { -- name
          elem_mods = { caption = station_data.name },
          actions = {
            on_click = { type = "depots", action = "position", position = station_data.station.position },
          },
        },
        { --status
          { elem_mods = { sprite = "flib_indicator_" .. status_color(station_data) } },
          { elem_mods = { caption = depot_limit(station_data) } },
        },
        { elem_mods = { caption = station_data.type } }, --type
        {}, --pusher
      })
    end

  end
  if table_index > 0 then
    vtm_gui.gui.tabs.depots_tab.badge_text = table_index
  end
  for child_index = table_index + 1, #children do
    children[child_index].destroy()
  end
end

local function build_gui(gui_id)
  local width = constants.gui.depots
  return {
    tab = {
      type = "tab",
      caption = { "vtm.tab-depots" },
      ref = { "tabs", "depots_tab" },
      name = "depots",
      actions = {
        on_click = { type = "generic", action = "change_tab", tab = "depots" },
      },
    },
    content = {
      type = "frame",
      style = "vtm_main_content_frame",
      direction = "vertical",
      ref = { "depots", "content_frame" },
      -- table header
      {
        type = "frame",
        style = "subheader_frame",
        direction = "horizontal",
        style_mods = { horizontally_stretchable = true },
        {
          type = "label",
          style = "subheader_caption_label",
          caption = { "vtm.table-header-name" },
          style_mods = { width = width.name },
        },
        {
          type = "label",
          style = "subheader_caption_label",
          caption = { "vtm.table-header-status" },
          style_mods = { width = width.status },
        },
        {
          type = "label",
          style = "subheader_caption_label",
          caption = { "vtm.table-header-type" },
          style_mods = { width = width.type },
          tooltip = "vtm.type-tooltip",
        },
        {
          type = "empty-widget",
          style = "flib_horizontal_pusher",
        },
        {
          type = "label",
          style = "subheader_caption_label",
          caption = { "vtm.table-header-stock" },
          style_mods = { width = width.stock, right_padding = width.appendix },
        },
        {
          type = "empty-widget",
          style_mods = { width = width.appendix }
        },
      },
      {
        type = "scroll-pane",
        style = "vtm_table_scroll_pane",
        ref = { "depots", "scroll_pane" },
        vertical_scroll_policy = "always",
        horizontal_scroll_policy = "auto",
      },
    },
  }
end

local function handle_action(action, event)
  if action.action == "position" then
    local player = game.players[event.player_index]
    if action.position then
      player.zoom_to_world(action.position, 0.5)
    else
      player.print("No position")
    end
  end
end

return {
  build_gui = build_gui,
  update_tab = update_tab,
  handle_action = handle_action,
}
