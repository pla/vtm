-- stations.lua
local misc = require("__flib__.misc")
local tables = require("__flib__.table")
local gui = require("__flib__.gui")
local gui_util = require("scripts.gui.utils")
local match = require("scripts.match")
local constants = require("scripts.constants")
local vtm_logic = require("scripts.vtm_logic")

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
  local color = "green"
  if limit == constants.MAX_LIMIT then
    limit = 1
  end
  local limit_text = inbound .. "/" .. limit
  if station_data.type == "R" then
    if inbound > 0 then
      color = "blue"
    elseif limit > 0 and inbound == 0 then
      color = "yellow"
    end
  else
    if limit == 0 and inbound > 0 then
      color = "yellow"
    elseif limit > 0 and inbound > 0 then
      color = "green"
    end
  end

  return limit_text, color

end

local function update_tab(gui_id)
  local vtm_gui = global.guis[gui_id]
  local stations = {}
  local nd_stations = 0
  local table_index = 0
  local max_lines = settings.global["vtm-limit-auto-refresh"].value

  local filters = {
    item = vtm_gui.gui.filter.item.elem_value,
    fluid = vtm_gui.gui.filter.fluid.elem_value,
    search_field = vtm_gui.gui.filter.search_field.text:lower(),
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
        if station_data.station.valid then
          table.insert(stations, station_data)
          -- only valid stations from here
        end
      end
    elseif station_data.force_index == vtm_gui.player.force.index and
        station_data.type == "ND"
    then
      nd_stations = nd_stations + 1
    end
  end

  local scroll_pane = vtm_gui.gui.stations.scroll_pane
  local children = scroll_pane.children
  local width = constants.gui.stations

  --sorting by name

  table.sort(stations, function(a, b) return a.station.backer_name < b.station.backer_name end)

  for _, station_data in pairs(stations) do

    if station_data.station.valid then
      if table_index >= max_lines and
          max_lines > 0 and
          global.settings[vtm_gui.player.index].gui_refresh == "auto" and
          filters.search_field == ""
      then
        -- max entries
        goto continue
      end

      table_index = table_index + 1
      vtm_gui.gui.stations.warning.visible = false
      -- get or create gui row
      -- name,status,since,avg,type,stock,intransit
      -- limit manual or circuit,type(PR),group
      local row = children[table_index]
      if not row then
        row = gui.add(scroll_pane, {
          type = "frame",
          direction = "horizontal",
          style = "vtm_table_row_frame",
          {
            type = "sprite-button",
            style = "transparent_slot",
            sprite = "vtm_train",
            tooltip = { "vtm.open-station-gui-tooltip" },
          },
          {
            type = "label",
            style = "vtm_clickable_semibold_label",
            style_mods = { width = width.name },
            tooltip = { "vtm.show-station-on-map-tooltip" },
          },
          {
            type = "flow",
            style = "flib_indicator_flow",
            style_mods = { width = width.status, horizontal_align = "left" },
            { type = "sprite", style = "flib_indicator" },
            { type = "label", style = "vtm_semibold_label" },
          },
          {
            type = "label",
            style = "vtm_semibold_label",
            style_mods = { width = width.since, horizontal_align = "right" },
          },
          {
            type = "label",
            style = "vtm_semibold_label",
            style_mods = { width = width.avg, horizontal_align = "right" },
          },
          {
            type = "label",
            style = "vtm_semibold_label",
            style_mods = { width = width.type, horizontal_align = "center" },
            tooltip = { "vtm.type-tooltip" },
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
      local limit_text, color = station_limit(station_data)
      local since = ""
      -- TODO Topic open requests
      -- if station_data.opened then
      --   since = misc.ticks_to_timestring(game.tick - station_data.opened)
      -- end
      local avg = "" --station_data.avg
      gui.update(row, {
        { -- Station button
          elem_mods = {
            sprite = "item/" .. gui_util.signal_for_entity(station_data.station).name,
          },
          actions = {
            on_click = { type = "stations", action = "open-station", station_id = station_data.station.unit_number },
          },
        },
        { -- name
          elem_mods = { caption = station_data.station.backer_name },
          actions = {
            on_click = { type = "stations", action = "position", position = station_data.station.position },
          },
        },
        { --status: InTransit =blue, open yellow, TODO : open for too long red
          { elem_mods = { sprite = "flib_indicator_" .. color } },
          { elem_mods = { caption = limit_text } },
        },
        { elem_mods = {
          caption = since
        } }, -- since
        { elem_mods = { caption = avg } }, -- avg
        { elem_mods = { caption = station_data.type } }, --type
      })
      gui_util.slot_table_update(row.stock_table, stock_data, vtm_gui.gui_id)
      gui_util.slot_table_update(row.in_transit_table, in_transit_data, vtm_gui.gui_id)
    end

  end
  ::continue::
  vtm_gui.gui.tabs.stations_tab.badge_text = table_index or 0
  if table_index > 0 then
    if nd_stations > 10 then
      vtm_gui.gui.stations.warning.visible = true
      vtm_gui.gui.stations.warning_label.caption = { "vtm.station-warning", nd_stations }
    end

  else
    vtm_gui.gui.stations.warning.visible = true
  end
  for child_index = table_index + 1, #children do
    children[child_index].destroy()
  end
end

local function build_gui(gui_id)
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
          -- caption = { "vtm.table-header-name" },
          style_mods = { width = width.icon },
        },
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
          -- caption = { "vtm.table-header-since" },
          style_mods = { width = width.since },
        },
        {
          type = "label",
          style = "subheader_caption_label",
          -- caption = { "vtm.table-header-avg" },
          style_mods = { width = width.avg },
        },
        {
          type = "label",
          style = "subheader_caption_label",
          caption = { "vtm.table-header-type" },
          style_mods = { width = width.type },
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
      {
        type = "frame",
        direction = "horizontal",
        style = "negative_subheader_frame",
        ref = { "stations", "warning" },
        visible = true,
        {
          type = "flow",
          style = "centering_horizontal_flow",
          style_mods = { horizontally_stretchable = true },
          {
            type = "label",
            style = "bold_label",
            caption = { "", "[img=warning-white] ", { "gui-trains.no-stations" } },
            ref = { "stations", "warning_label" },
          },
        },
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
