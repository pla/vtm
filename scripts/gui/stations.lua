-- stations.lua
local tables    = require("__flib__.table")
-- local gui         = require("__flib__.gui")
local gui         = require("__virtm__.scripts.flib-gui")
local gui_util  = require("__virtm__.scripts.gui.utils")
local match     = require("__virtm__.scripts.match")
local constants = require("__virtm__.scripts.constants")
local vtm_logic = require("__virtm__.scripts.vtm_logic")
local groups    = require("__virtm__.scripts.gui.groups")

---comment
---@param station_data StationData
---@param is_circuit_limit boolean
---@return string limit_text
---@return string color
local function station_limit(station_data, is_circuit_limit)
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
  if not is_circuit_limit then
    limit_text = limit_text .. " m"
  end
  return limit_text, color
end

local function update_tab(gui_id)
  local vtm_gui = storage.guis[gui_id]
  local surface = storage.settings[storage.guis[gui_id].player.index].surface or "All"
  ---@type table<uint,StationData>
  local stations = {}
  local nd_stations = 0
  local table_index = 0
  local max_lines = storage.max_lines

  local filters = {
    search_field = vtm_gui.gui.filter.search_field.text:lower(),
  }

  if not next(storage.stations) then
    vtm_logic.init_stations()
  end
  for _, station_data in pairs(storage.stations) do
    if station_data.station.valid and
        (surface == "All" or surface == station_data.station.surface.name)
    then
      -- only valid stations from here
      if station_data.force_index == vtm_gui.player.force.index and
          (station_data.type == "R" or station_data.type == "P")
      then
        if match.filter_stations(station_data, filters) then
          table.insert(stations, station_data)
        end
      elseif station_data.force_index == vtm_gui.player.force.index and
          station_data.type == "ND"
      then
        -- TODO setting abfragen
        nd_stations = nd_stations + 1
      end
    end
  end

  local scroll_pane = vtm_gui.gui.stations.scroll_pane or {}
  local children = scroll_pane.children
  local width = constants.gui.stations

  --sorting by name

  table.sort(stations, function(a, b) return a.station.backer_name < b.station.backer_name end)

  for _, station_data in pairs(stations) do
    if station_data.station.valid then
      if table_index >= max_lines and
          max_lines > 0 and
          storage.settings[vtm_gui.player.index].gui_refresh == "auto" and
          filters.search_field == ""
      then
        -- max entries, loop verlasen
        break
      end

      table_index = table_index + 1
      vtm_gui.gui.stations.warning.visible = false
      -- get or create gui row
      -- name,status,prio,type,stock,intransit
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
            style_mods = { size = width.icon },
            sprite = "utility/side_menu_train_icon",
            -- tooltip = { "gui-train.open-in-map" },
            tooltip = { "vtm.open-station-gui-tooltip" },
          },
          {
            type = "label",
            style = "vtm_clickable_semibold_label_with_padding",
            style_mods = { width = width.name },
            tooltip = { "gui-train.open-in-map" },
            -- tooltip = { "vtm.show-station-on-map-tooltip" },
          },
          {
            type = "flow",
            style = "flib_indicator_flow",
            style_mods = { width = width.status, horizontal_align = "left" },
            { type = "sprite", style = "flib_indicator" },
            { type = "label",  style = "vtm_semibold_label_with_padding" },
          },
          {
            type = "label",
            style = "vtm_semibold_label_with_padding",
            style_mods = { width = width.prio, horizontal_align = "right" },
          },
          {
            type = "label",
            style = "vtm_semibold_label_with_padding",
            style_mods = { width = width.type, horizontal_align = "center" },
            tooltip = { "vtm.type-tooltip" },
          },
          gui_util.slot_table(width, nil, "stock"),
          gui_util.slot_table(width, nil, "in_transit"),
          {
            type = "empty-widget",
            style = "flib_horizontal_pusher",
            ignored_by_interaction = true
          },
          {
            type = "frame",
            style = "vtm_bordered_frame_no_padding",
            {
              -- groups button
              type = "sprite-button",
              style = "transparent_slot",
              style_mods = { size = 32 },
              sprite = "utility/expand",
              tooltip = { "vtm.stations-open-groups-tooltip" },
            },
          }
        })
      end
      -- insert data
      -- name,status,prio,type,stock,intransit
      -- limit manual or circuit,type(PR),group
      local stock_data, is_circuit_limit = vtm_logic.read_station_network(station_data)
      station_data.stock = stock_data
      station_data.stock_tick = game.tick
      local group_id, sprite
      if station_data.type == "P" then
        group_id = vtm_logic.read_group_id(station_data.station)
      end
      if group_id then
        sprite = "vtm_group_logo"
      else
        sprite = "utility/expand"
      end
      local in_transit_data = {}
      if station_data.station.trains_count > 0 then
        in_transit_data = gui_util.read_inbound_trains(station_data)
      end
      local limit_text, color = station_limit(station_data, is_circuit_limit)
      local prio = ""
      gui.update(row, {
        {
          -- Station button
          elem_mods = {
            sprite = station_data.sprite,
          },
          actions = {
            on_click = { type = "stations", action = "open-station", station_id = station_data.station.unit_number },
          },
        },
        {
          -- name
          elem_mods = { caption = station_data.station.backer_name },
          actions = {
            on_click = { type = "stations", action = "position", station_id = station_data.station.unit_number },
          },
        },
        { --status: InTransit =blue, open yellow, TODO : open for too long red
          { elem_mods = { sprite = "flib_indicator_" .. color } },
          { elem_mods = { caption = limit_text } },
        },
        {
          elem_mods = { --TODO change prio popup
            caption = station_data.station.train_stop_priority
          }
        },                                               -- prio
        { elem_mods = { caption = station_data.type } }, --type
        {}, {}, {},                                      -- slot table, slot table, pusher
        { {
          --groups button
          elem_mods = {
            sprite = sprite,
          },
          actions = {
            on_click = { type = "stations", action = "show_group_ui", group_id = group_id, gui_id = gui_id },
          },
        }
        }
      })
      gui_util.slot_table_update(row.stock_table, station_data.stock, vtm_gui.gui_id)
      gui_util.slot_table_update(row.in_transit_table, in_transit_data, vtm_gui.gui_id)
    end
  end
  vtm_gui.gui.tabs.stations_tab.badge_text = table_index or 0
  if table_index > 0 then
    if nd_stations > 10 and storage.show_undef_warn  then
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

  -- name,status,prio,type,stock,intransit
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
          caption = { "vtm.table-header-prio" },
          style_mods = { width = width.prio },
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
          style = "compact_horizontal_flow",
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

---comment
---@param action GuiAction
---@param event EventData|any
local function handle_action(action, event)
  if action.action == "open-station" then
    if storage.stations[action.station_id] then
      local station = storage.stations[action.station_id].station --[[@as LuaEntity]]
      if not station.valid then return end
      gui_util.open_entity_gui(event.player_index, station)
    end
  elseif action.action == "position" then
    local player = game.players[event.player_index]
    local position, surface
    if action.station_id then
      local station = storage.stations[action.station_id].station --[[@as LuaEntity]]
      if not station.valid then return end
      position = station.position --[[@as MapPosition]]
      surface = station.surface.name --[[@as string]]
    elseif action.position and action.surface_name then
      position = action.position --[[@as MapPosition]]
      surface = action.surface_name --[[@as string]]
    end
      -- player.zoom_to_world(position, 0.5)
      player.set_controller({type = defines.controllers.remote, position = position, surface = surface})
  elseif action.action == "show_group_ui" then
    local player = game.players[event.player_index]
    groups.open_gui(action)
  end
end

return {
  build_gui = build_gui,
  update_tab = update_tab,
  handle_action = handle_action
}
