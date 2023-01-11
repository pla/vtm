-- stations.lua
local misc = require("__flib__.misc")
local tables = require("__flib__.table")
local gui = require("__flib__.gui")
local gui_util = require("scripts.gui.util")
local match = require("scripts.match")
local constants = require("scripts.constants")
local vtm_logic = require("scripts.vtm_logic")

local function status_color(station)
  -- FIXME: actually do something
  return "green"
end

local function read_inbound_trains(station_data)
  local station = station_data.station
  local contents = {}
  if station.valid then
    local trains = global.trains
    for _, train_data in pairs(trains) do
      if train_data.path_end_stop == station.unit_number then
        for k, y in pairs(train_data.contents) do
          local row = {}
          row.type = k == "items" and "item" or "fluid"
          for name, count in pairs(y) do
            row.name = name
            row.count = count
            row.color = "blue"
            table.insert(contents, row)
          end
        end
      end
    end
  end
  return contents

end

local function read_station_network(station_data, return_virtual)
  local station = station_data.station
  local contents = {}
  local colors = tables.invert(defines.wire_type)
  if station.valid then
    for _, wire in pairs({ defines.wire_type.red, defines.wire_type.green }) do
      local cn = station.get_circuit_network(wire)
      -- cn - signals (type,name),wire_type
      if cn ~= nil and cn.signals ~= nil then
        for _, signal_data in pairs(cn.signals) do
          if signal_data.signal.type == "virtual" and return_virtual ~= true then
            goto continue
          end
          table.insert(contents, {
            type = signal_data.signal.type,
            name = signal_data.signal.name,
            count = signal_data.count,
            color = colors[wire]
          })
          ::continue::
        end
      end
    end
  end
  return contents
end

local function station_limit(station_data)
  local limit = station_data.station.trains_limit
  local inbound = station_data.station.trains_count
  if limit == constants.MAX_LIMIT then
    limit = 1
  end
  return inbound .. "/" .. limit
end

local function update_tab(gui_id)
  local vtm_gui = global.guis[gui_id]
  local stations = {}

  local table_index = 0
  local filters = {
    item = vtm_gui.gui.filter.item.elem_value,
    fluid = vtm_gui.gui.filter.fluid.elem_value,
    search_field = vtm_gui.gui.filter.search_field.text:lower(),
    -- time_period = game.tick - time_filter.ticks(vtm_gui.gui.filter.time_period.selected_index)
  }

  if not next(global.stations) then
    vtm_logic.init_stations()
  end
  for _, station_data in pairs(global.stations) do
    if station_data.force_index == vtm_gui.player.force.index and
        (station_data.type == "R" or
            station_data.type == "P")
    then
      if match.filter_stations(station_data, filters) then

        table.insert(stations, station_data)
      end
    end
  end
  -- TODO filter contents


  local scroll_pane = vtm_gui.gui.stations.scroll_pane
  local children = scroll_pane.children
  local width = constants.gui.stations

  for _, station_data in pairs(stations) do

    if station_data.station.valid then
      table_index = table_index + 1
      -- get or create gui row
      -- name,status,since,avg,type,stock,intransit
      -- limit manual or circuit,type(PR),group
      local row = children[table_index]
      local color = table_index % 2 == 0 and "dark" or "light"
      if not row then
        row = gui.add(scroll_pane, {
          type = "frame",
          direction = "horizontal",
          style = "vtm_table_row_frame",
          -- style = " vtm_table_row_frame_" .. color,
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
            style_mods = { width = width.since },
          },
          {
            type = "label",
            style = "vtm_semibold_label",
            style_mods = { width = width.avg },
          },
          {
            type = "label",
            style = "vtm_semibold_label",
            style_mods = { width = width.type, },
          },
          gui_util.slot_table(width, "light", "stock"),
          gui_util.slot_table(width, "light", "in_transit"),
        })
      end
      -- insert data
      -- name,status,since,avg,type,stock,intransit
      -- limit manual or circuit,type(PR),group
      local stock_data = read_station_network(station_data)
      local in_transit_data = {}
      if station_data.station.trains_count > 0 then
        in_transit_data = read_inbound_trains(station_data)
      end
      local since = ""
      -- if station_data.opened then
      --   since = misc.ticks_to_timestring(game.tick - station_data.opened)
      -- end
      gui.update(row, {
        { -- name
          elem_mods = { caption = station_data.station.backer_name },
          actions = {
            on_click = { type = "stations", action = "open-station", station_id = station_data.station.unit_number },
          },
        },
        { --status
          { elem_mods = { sprite = "flib_indicator_" .. status_color(station_data.station) } },
          { elem_mods = { caption = station_limit(station_data) } },
        },
        { elem_mods = {
          caption = since
        } }, -- since
        { elem_mods = { caption = station_data.avg } }, -- avg
        { elem_mods = { caption = station_data.type } }, --type
      })
      gui_util.slot_table_update(row.stock_table, stock_data, vtm_gui.gui_id)
      gui_util.slot_table_update(row.in_transit_table, in_transit_data, vtm_gui.gui_id)
    end

  end
  if table_index > 0 then
    vtm_gui.gui.tabs.stations_tab.badge_text = table_index
  end
  for child_index = table_index + 1, #children do
    children[child_index].destroy()
  end
end

local function build_gui(gui_id)
  -- local vtm_gui = global.guis[gui_id]
  -- local tabs = vtm_gui.gui.tabs
  local width = constants.gui.stations

  -- name,status,since,avg,type,stock,intransit
  -- limit manual or circuit,type(PR),group
  return {
    tab = {
      type = "tab",
      caption = { "gui-trains.stations-tab" },
      ref = { "tabs", "stations_tab" },
      name = "stations",
      actions = {
        on_click = { type = "generic", action = "change_tab", tab = "stations" },
      },
    },
    content = {
      type = "frame",
      style = "vtm_main_content_frame",
      direction = "vertical",
      ref = { "stations", "content_frame" },
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
          caption = { "vtm.table-header-since" },
          style_mods = { width = width.since },
        },
        {
          type = "label",
          style = "subheader_caption_label",
          caption = { "vtm.table-header-avg" },
          style_mods = { width = width.avg },
        },
        {
          type = "label",
          style = "subheader_caption_label",
          caption = { "vtm.table-header-type" },
          style_mods = { width = width.type },
          tooltip = "vtm.type-tooltip",
        },
        {
          type = "label",
          style = "subheader_caption_label",
          caption = { "vtm.table-header-stock" },
          style_mods = { width = width.stock },
        },
        {
          type = "label",
          style = "subheader_caption_label",
          caption = { "vtm.table-header-in-transit" },
          style_mods = { width = width.in_transit },
        },
      },
      {
        type = "scroll-pane",
        style = "vtm_table_scroll_pane",
        ref = { "stations", "scroll_pane" },
        vertical_scroll_policy = "always",
        horizontal_scroll_policy = "never",
        -- style_mods = {  },
      },
    },
  }
end

local function handle_action(action, event)
  if action.action == "open-station" then
    if global.stations[action.station_id] then
      local station = global.stations[action.station_id].station --[[@as LuaEntity]]
      gui_util.open_gui(event.player_index, station)
    end
  elseif action.action == "refresh" then
    local player = game.players[event.player_index]

  elseif action.action == "position" then
    local player = game.players[event.player_index]
    player.zoom_to_world(action.position, 0.5)
  end
end

return {
  build_gui = build_gui,
  update_tab = update_tab,
  handle_action = handle_action
}
