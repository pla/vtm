-- depots.lua
local constants = require("scripts.constants")
local tables = require("__flib__.table")
local gui = require("__flib__.gui")
local gui_util = require("scripts.gui.utils")
local match = require("scripts.match")
local vtm_logic = require("scripts.vtm_logic")

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
  for item, amount in pairs(stock.items or {}) do
    if all_stock[item] then
      all_stock[item].count = all_stock[item].count + amount
    else
      all_stock[item] = { type = "item", name = item, count = amount, color = nil }
    end
  end

  for item, amount in pairs(stock.fluids or {}) do
    if all_stock[item] then
      all_stock[item].count = all_stock[item].count + amount
    else
      all_stock[item] = { type = "fluid", name = item, count = amount, color = nil }
    end
  end

end

local function read_depot_cargo(station_data)
  local station_stock = {}
  if not station_data.station.valid then return {} end
  local trains = station_data.station.get_train_stop_trains()
  for _, t in pairs(trains) do
    -- check if the train is at the station
    for _, rail in pairs(station_data.rails) do
      if t.front_rail.is_rail_in_same_rail_block_as(rail) then
        local stock = {}
        stock.items = t.get_contents()
        stock.fluids = t.get_fluid_contents()
        add_stock(stock, station_stock)
        goto continue
      end
    end
    ::continue::
  end
  return station_stock
end

local function update_tab(gui_id)
  local vtm_gui = global.guis[gui_id]
  local depots_compact = {}
  local depots = {}
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
          tables.insert(depots_compact[station_data.station.backer_name].rails,
            station_data.station.connected_rail)
        else
          -- new record
          depots_compact[station_data.station.backer_name] = {
            station = station_data.station,
            name = station_data.station.backer_name,
            type = station_data.type,
            inbound = station_data.station.trains_count,
            limit = limit,
            sort_prio = station_data.sort_prio,
            rails = { station_data.station.connected_rail, },
            stock = {}
          }
        end
      end
    end
  end
  -- only valid stations from here
  local scroll_pane = vtm_gui.gui.depots.scroll_pane
  local children = scroll_pane.children
  local width = constants.gui.depots
  -- new table to make sorting possible
  for _, value in pairs(depots_compact) do
    table.insert(depots, value)
  end
  --sorting by name and type
  if game.active_mods["Train_Control_Signals"] then
    -- special sort for TCS icons, depots always first
    table.sort(depots, function(a, b) return a.sort_prio .. a.name < b.sort_prio .. b.name end)
  else
    table.sort(depots, function(a, b) return a.type .. a.name < b.type .. b.name end)
  end

  for _, station_data in pairs(depots) do

    if station_data.station.valid then
      table_index = table_index + 1
      vtm_gui.gui.depots.warning.visible = false
      -- get or create gui row
      local row = children[table_index]
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
            tooltip = { "vtm.show-station-on-map-tooltip" },
          },
          {
            type = "flow",
            style = "flib_indicator_flow",
            style_mods = { width = width.status, horizontal_align = "left", },
            { type = "sprite", style = "flib_indicator" },
            { type = "label", style = "vtm_semibold_label" },
          },
          {
            type = "label",
            style = "vtm_semibold_label",
            style_mods = { width = width.type, horizontal_align = "center", },
            tooltip = { "vtm.type-depot-tooltip" },
          },
          gui_util.slot_table(width, "light", "stock"),
        })
      end
      -- read cargo from trains parking at depot
      local station_stock = {}
      if station_data.inbound > 0 then
        station_stock = read_depot_cargo(station_data)
      end
      local limit_text, color = depot_limit(station_data)

      -- insert data
      gui.update(row, {
        { -- name
          elem_mods = { caption = station_data.name },
          actions = {
            on_click = { type = "depots", action = "position", position = station_data.station.position },
          },
        },
        { --status
          { elem_mods = { sprite = "flib_indicator_" .. color } },
          { elem_mods = { caption = limit_text } },
        },
        { elem_mods = { caption = station_data.type } }, --type
        -- {}, --pusher
        gui_util.slot_table_update(row.stock_table, station_stock, vtm_gui.gui_id)
      })
    end
  end
  vtm_gui.gui.tabs.depots_tab.badge_text = table_index
  if table_index == 0 then
    vtm_gui.gui.depots.warning.visible = true
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
        },
        -- {
        --   type = "empty-widget",
        --   style = "flib_horizontal_pusher",
        -- },
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
        ref = { "depots", "scroll_pane" },
        vertical_scroll_policy = "always",
        horizontal_scroll_policy = "auto",
      },
      {
        type = "frame",
        direction = "horizontal",
        style = "negative_subheader_frame",
        ref = { "depots", "warning" },
        visible = true,
        {
          type = "flow",
          style = "centering_horizontal_flow",
          style_mods = { horizontally_stretchable = true },
          {
            type = "label",
            style = "bold_label",
            caption = { "", "[img=warning-white] ", { "gui-trains.no-stations" } },
            ref = { "depots", "warning_label" },
          },
        },
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
