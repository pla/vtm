-- depots.lua
local constants = require("__virtm__.scripts.constants")
local flib_table = require("__flib__.table")
local flib_gui = require("__flib__.gui")
local gui_utils = require("__virtm__.scripts.gui.utils")
local searchbar = require("__virtm__.scripts.gui.searchbar")

local depots = {}

local function depot_limit(station_data)
  local limit = station_data.limit
  local inbound = station_data.inbound
  local limit_text = inbound .. "/" .. limit
  local color = "green"
  if (limit == inbound or limit - 1 == inbound) and limit > 1 then
    color = "red"
  elseif inbound > limit - 3 and limit > 10 then
    color = "yellow"
  end
  return limit_text, color
end

local function add_stock(stock, all_stock)
  for _, item in pairs(stock.items or {}) do
    local key = item.name .. item.quality
    if all_stock[key] then
      all_stock[key].count = all_stock[key].count + item.count
    else
      all_stock[key] = { type = "item", name = item.name, count = item.count, quality = item.quality }
    end
  end

  for fluid, count in pairs(stock.fluids or {}) do
    local key = fluid
    if all_stock[key] then
      all_stock[key].count = all_stock[key].count + count
    else
      all_stock[key] = { type = "fluid", name = fluid, count = count }
    end
  end
end

local function read_depot_cargo(station_data)
  local station_stock = {}
  if not station_data.station.valid then
    return {}
  end
  local tm = game.train_manager
  -- local surface = station_data.station.surface
  local depots = tm.get_train_stops({
    force = station_data.station.force,
    station_name = station_data.station.backer_name,
  })
  for _, s in pairs(depots) do
    local stock = {}
    local t = s.get_stopped_train()
    if t then
      stock.items = t.get_contents()
      stock.fluids = t.get_fluid_contents()
      add_stock(stock, station_stock)
    end
  end
  return station_stock
end

--- @param gui_data GuiData
--- @param event EventData|EventData.on_gui_click
function depots.show_depot(gui_data, event)
  gui_utils.show_station(gui_data, event)
end

function depots.update_tab(gui_data, event)
  local player = gui_data.player
  local surface = storage.settings[player.index].surface or "All"
  local depots_compact = {}
  local depots_datas = {}
  local limit
  local table_index = 0

  for _, station_data in pairs(storage.stations) do
    if station_data.force_index == player.force.index and (station_data.type == "D" or station_data.type == "F") then
      if station_data.station.valid and (surface == "All" or surface == station_data.station.surface.name) then
        -- record present
        limit = station_data.station.trains_limit
        if limit == constants.MAX_LIMIT then
          limit = 1
        end
        if depots_compact[station_data.station.backer_name] then
          depots_compact[station_data.station.backer_name].limit = depots_compact[station_data.station.backer_name].limit
            + limit

          depots_compact[station_data.station.backer_name].inbound = depots_compact[station_data.station.backer_name].inbound
            + station_data.station.trains_count
          flib_table.insert(depots_compact[station_data.station.backer_name].rails, station_data.station.connected_rail)
        else
          -- new record
          depots_compact[station_data.station.backer_name] = {
            station = station_data.station,
            name = station_data.station.backer_name,
            type = station_data.type,
            inbound = station_data.station.trains_count,
            limit = limit,
            sort_prio = station_data.sort_prio,
            rails = { station_data.station.connected_rail },
            stock = {},
          }
        end
      end
    end
  end
  -- only valid stations from here
  local scroll_pane = gui_data.gui.depots_scrollpane or {}
  local children = scroll_pane.children
  local width = constants.gui.depots
  -- new table to make sorting possible
  for _, value in pairs(depots_compact) do
    table.insert(depots_datas, value)
  end
  --sorting by name and type
  if storage.TCS_active then
    -- special sort for TCS icons, depots always first
    table.sort(depots_datas, function(a, b)
      return a.sort_prio .. a.name < b.sort_prio .. b.name
    end)
  else
    table.sort(depots_datas, function(a, b)
      return a.type .. a.name < b.type .. b.name
    end)
  end
  -- finish when not current tab
  if storage.settings[gui_data.player.index].current_tab ~= "depots" then
    gui_data.gui.depots.badge_text = table_size(depots_datas)
    return
  end

  for _, station_data in pairs(depots_datas) do
    if station_data.station.valid then
      table_index = table_index + 1
      gui_data.gui.depots_warning.visible = false
      -- get or create gui row
      local row = children[table_index]
      local refs = {}
      if not row then
        local gui_contents = {
          type = "frame",
          direction = "horizontal",
          style = "vtm_table_row_frame",
          {
            type = "label",
            name = "depot_name",
            style = "vtm_clickable_semibold_label_with_padding",
            style_mods = { width = width.name },
            tooltip = { "vtm.show-station-on-map-tooltip" },
            handler = { [defines.events.on_gui_click] = depots.show_depot },
          },
          {
            type = "flow",
            name = "indicator",
            style = "flib_indicator_flow",
            style_mods = { width = width.status },
            { type = "sprite", style = "flib_indicator" },
            { type = "label", style = "vtm_semibold_label_with_padding" },
          },
          {
            type = "label",
            name = "depot_type",
            style = "vtm_semibold_label_with_padding",
            style_mods = { width = width.type, horizontal_align = "center" },
            tooltip = { "vtm.type-depot-tooltip" },
          },
          gui_utils.slot_table(width, nil, "stock"),
        }
        refs, row = flib_gui.add(scroll_pane, gui_contents)
      end
      -- read cargo from trains parking at depot
      local station_stock = {}
      if station_data.inbound > 0 and not storage.dont_read_depot_stock then
        station_stock = read_depot_cargo(station_data)
        if station_data.station.name == "se-space-elevator" then
          station_stock = gui_utils.read_inbound_trains(station_data)
        end
      end
      local limit_text, color = depot_limit(station_data)
      if table_size(refs) == 0 then
        refs = gui_utils.recreate_gui_refs(row)
      end
      -- insert data
      refs.depot_name.caption = station_data.name
      refs.depot_name.tags =
        flib_table.shallow_merge({ refs.depot_name.tags, { station_id = station_data.station.unit_number } })
      refs.indicator.children[1].sprite = "flib_indicator_" .. color
      refs.indicator.children[2].caption = limit_text
      refs.depot_type.caption = station_data.type
      gui_utils.slot_table_update(row.stock_table, station_stock, searchbar.apply_filter)
    end
  end
  gui_data.gui.depots.badge_text = table_index
  if table_index == 0 then
    gui_data.gui.depots_warning.visible = true
  end
  for child_index = table_index + 1, #children do
    children[child_index].destroy()
  end
end

function depots.build_tab(gui_id)
  local width = constants.gui.depots
  return {
    tab = {
      type = "tab",
      caption = { "vtm.tab-depots" },
      name = "depots",
    },
    content = {
      type = "frame",
      style = "vtm_main_content_frame",
      direction = "vertical",
      name = "depots_content_frame",
      -- table header
      {
        type = "frame",
        style = "subheader_frame",
        direction = "horizontal",
        style_mods = { horizontally_stretchable = true, left_padding = 4 },
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
        },
        {
          type = "label",
          style = "subheader_caption_label",
          caption = { "vtm.table-header-stock" },
          style_mods = { width = width.stock },
        },
      },
      {
        type = "scroll-pane",
        style = "vtm_table_scroll_pane",
        name = "depots_scrollpane",
        vertical_scroll_policy = "always",
        horizontal_scroll_policy = "auto",
      },
      {
        type = "frame",
        direction = "horizontal",
        style = "negative_subheader_frame",
        name = "depots_warning",
        visible = true,
        {
          type = "flow",
          style = "compact_horizontal_flow",
          style_mods = { horizontally_stretchable = true },
          {
            type = "label",
            style = "bold_label",
            caption = { "", "[img=warning-white] ", { "gui-trains.no-stations" } },
            name = "depots_warning_label",
          },
        },
      },
    },
  }
end

flib_gui.add_handlers(depots, function(event, handler)
  local gui_id = gui_utils.get_gui_id(event.player_index)
  ---@type GuiData
  local gui_data = storage.guis[gui_id]
  if gui_data then
    handler(gui_data, event)
  end
end, "depots")

return depots
