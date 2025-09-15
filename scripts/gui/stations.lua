-- stations.lua
local flib_gui = require("__flib__.gui")
local flib_table = require("__flib__.table")
local gui_utils = require("__virtm__.scripts.gui.utils")
local match = require("__virtm__.scripts.match")
local constants = require("__virtm__.scripts.constants")
local backend = require("__virtm__.scripts.backend")
local groups_tab = require("__virtm__.scripts.gui.groups-tab")
local searchbar = require("__virtm__.scripts.gui.searchbar")

local stations = {}
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

--- @param gui_data GuiData
--- @param event? EventData|EventData.on_gui_click
function stations.update_tab(gui_data, event)
  local surface = storage.settings[gui_data.player.index].surface or "All"
  ---@type StationData[]
  local station_datas = {}
  local nd_stations = 0
  local table_index = 0
  local max_lines = storage.max_lines

  local filters = {
    search_field = gui_data.gui.search_field.text:lower(),
  }

  if not next(storage.stations) then
    backend.init_stations()
  end
  for _, station_data in pairs(storage.stations) do
    if station_data.station.valid and (surface == "All" or surface == station_data.station.surface.name) then
      -- only valid stations from here
      if
        station_data.force_index == gui_data.player.force.index
        and (station_data.type == "R" or station_data.type == "P")
      then
        if match.filter_stations(station_data, filters) then
          table.insert(station_datas, station_data)
        end
      elseif station_data.force_index == gui_data.player.force.index and station_data.type == "ND" then
        nd_stations = nd_stations + 1
      end
    end
  end
  -- finish when not current tab
  if storage.settings[gui_data.player.index].current_tab ~= "stations" then
    gui_data.gui.stations.badge_text = table_size(station_datas)
    return
  end
  local scroll_pane = gui_data.gui.stations_scrollpane
  local children = scroll_pane.children
  local width = constants.gui.stations

  --sorting by name

  table.sort(station_datas, function(a, b)
    return a.station.backer_name < b.station.backer_name
  end)

  for _, station_data in pairs(station_datas) do
    if station_data.station.valid then
      if
        table_index >= max_lines
        and max_lines > 0
        and storage.settings[gui_data.player.index].gui_refresh == "auto"
        and filters.search_field == ""
      then
        -- max entries, loop verlasen
        break
      end

      table_index = table_index + 1
      gui_data.gui.stations_warning.visible = false
      -- get or create gui row
      -- name,status,prio,type,stock,intransit
      -- limit manual or circuit,type(PR),group
      local row = children[table_index]
      local refs = {}
      if not row then
        local gui_contents = {
          type = "frame",
          -- name = "row_frame",
          direction = "horizontal",
          style = "vtm_table_row_frame",
          {
            type = "sprite-button",
            name = "stations_sprite",
            style = "transparent_slot",
            style_mods = { size = width.icon },
            sprite = "utility/side_menu_train_icon",
            tooltip = { "vtm.open-station-gui-tooltip" },
            handler = { [defines.events.on_gui_click] = stations.open_station },
          },
          {
            type = "label",
            name = "station_name",
            style = "vtm_clickable_semibold_label_with_padding",
            style_mods = { width = width.name },
            tooltip = { "gui-train.open-in-map" },
            -- tooltip = { "vtm.show-station-on-map-tooltip" },
            handler = { [defines.events.on_gui_click] = stations.show_station },
          },
          {
            type = "flow",
            name = "indicator",
            style = "flib_indicator_flow",
            style_mods = { width = width.status, horizontal_align = "left" },
            { type = "sprite", style = "flib_indicator" },
            { type = "label", style = "vtm_semibold_label_with_padding" },
          },
          {
            type = "label",
            name = "prio",
            style = "vtm_semibold_label_with_padding",
            style_mods = { width = width.prio, horizontal_align = "right" },
          },
          {
            type = "label",
            name = "station_type",
            style = "vtm_semibold_label_with_padding",
            style_mods = { width = width.type, horizontal_align = "center" },
            tooltip = { "vtm.type-tooltip" },
          },
          gui_utils.slot_table(width, nil, "stock"),
          gui_utils.slot_table(width, nil, "in_transit"),
          {
            type = "empty-widget",
            style = "flib_horizontal_pusher",
            ignored_by_interaction = true,
          },
          {
            type = "frame",
            style = "vtm_bordered_frame_no_padding",
            {
              -- groups button
              type = "sprite-button",
              name = "groups_button",
              style = "transparent_slot",
              style_mods = { size = 32 },
              sprite = "utility/expand",
              tooltip = { "vtm.stations-open-groups-tooltip" },
              handler = { [defines.events.on_gui_click] = stations.show_group_ui },
            },
          },
        }
        refs, row = flib_gui.add(scroll_pane, gui_contents)
      end
      -- insert data
      -- name,status,prio,type,stock,intransit
      -- limit manual or circuit,type(PR),group
      row.visible = true
      local stock_data, is_circuit_limit = backend.read_station_network(station_data)
      station_data.stock = stock_data
      station_data.stock_tick = game.tick
      local group_id, sprite, tooltip
      if station_data.type == "P" then
        group_id = backend.read_group_id(station_data.station)
      end
      if group_id then
        sprite = "vtm_group_logo"
        tooltip = { "vtm.stations-open-groups-tooltip" }
      else
        sprite = "utility/expand"
        tooltip = ""
      end
      local in_transit_data = {}
      if station_data.station.trains_count > 0 then
        in_transit_data = gui_utils.read_inbound_trains(station_data)
      end
      local limit_text, color = station_limit(station_data, is_circuit_limit)
      if table_size(refs) == 0 then
        refs = gui_utils.recreate_gui_refs(row)
      end
      -- Fill with data
      refs.stations_sprite.sprite = station_data.sprite
      refs.stations_sprite.tags = flib_table.shallow_merge({
        refs.stations_sprite.tags,
        { station_id = station_data.station.unit_number },
      })
      refs.station_name.caption = station_data.station.backer_name
      refs.station_name.tags =
        flib_table.shallow_merge({ refs.station_name.tags, { station_id = station_data.station.unit_number } })
      --status: InTransit =blue, open yellow
      refs.indicator.children[1].sprite = "flib_indicator_" .. color
      refs.indicator.children[2].caption = limit_text
      refs.prio.caption = station_data.station.train_stop_priority
      refs.station_type.caption = station_data.type
      refs.groups_button.sprite = sprite
      refs.groups_button.tooltip = tooltip
      if group_id then
        refs.groups_button.tags = flib_table.shallow_merge({ refs.groups_button.tags, { group_id = group_id } })
      else
        refs.groups_button.tags = {}
      end

      gui_utils.slot_table_update(row.stock_table, station_data.stock, searchbar.apply_filter)
      gui_utils.slot_table_update(row.in_transit_table, in_transit_data, searchbar.apply_filter)
    end
  end
  gui_data.gui.stations.badge_text = table_index or 0
  if table_index > 0 then
    if nd_stations > 10 and storage.show_undef_warn then
      gui_data.gui.stations_warning.visible = true
      gui_data.gui.stations_warning_label.caption = { "vtm.station-warning", nd_stations }
    end
  else
    gui_data.gui.stations_warning.visible = true
  end
  for child_index = table_index + 1, #children do
    -- children[child_index].destroy()
    children[child_index].visible = false
  end
end

function stations.build_tab(gui_id)
  local width = constants.gui.stations

  -- name,status,prio,type,stock,intransit
  -- limit manual or circuit,type(PR),group
  return {
    tab = {
      type = "tab",
      caption = { "gui-trains.stations-tab" },
      name = "stations",
    },
    content = {
      type = "frame",
      name = "stations_content_frame",
      style = "vtm_main_content_frame",
      direction = "vertical",
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
        name = "stations_scrollpane",
        style = "vtm_table_scroll_pane",
        vertical_scroll_policy = "always",
        horizontal_scroll_policy = "never",
      },
      {
        type = "frame",
        direction = "horizontal",
        style = "negative_subheader_frame",
        name = "stations_warning",
        visible = true,
        {
          type = "flow",
          style = "compact_horizontal_flow",
          style_mods = { horizontally_stretchable = true },
          {
            type = "label",
            style = "bold_label",
            caption = { "", "[img=warning-white] ", { "gui-trains.no-stations" } },
            name = "stations_warning_label",
          },
        },
      },
    },
  }
end

--- @param gui_data GuiData
--- @param event EventData|EventData.on_gui_click
function stations.open_station(gui_data, event)
  gui_utils.open_station(gui_data, event)
end

--- @param gui_data GuiData
--- @param event EventData|EventData.on_gui_click
function stations.show_station(gui_data, event)
  gui_utils.show_station(gui_data, event)
end

--- @param gui_data GuiData
--- @param event EventData|EventData.on_gui_click
function stations.show_group_ui(gui_data, event)
  if event.element.tags and event.element.tags.group_id then
    group_id = event.element.tags.group_id
  else
    return
  end
  groups_tab.open_group_edit(gui_data, event)
end

flib_gui.add_handlers(stations, function(event, handler)
  local gui_id = gui_utils.get_gui_id(event.player_index)
  ---@type GuiData
  local gui_data = storage.guis[gui_id]
  if gui_data then
    handler(gui_data, event)
  end
end, "stations")

return stations
