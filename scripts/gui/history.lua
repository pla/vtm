-- history.lua
local util = require("__core__.lualib.util")
local gui = require("__flib__.gui")
local gui_util = require("__vtm__.scripts.gui.utils")
local match = require("__vtm__.scripts.match")
local constants = require("__vtm__.scripts.constants")
local format = require("__flib__.format")

local function material_icon_list(event)
  local result = ""
  -- diff only after leaving station
  if event.diff then
    for item, amount in pairs(event.diff.items or {}) do
      result = result .. amount .. " [item=" .. item .. "], "
    end
    for fluid, amount in pairs(event.diff.fluids or {}) do
      result = result .. math.abs(amount) .. " [fluid=" .. fluid .. "], "
    end
  end
  --contents and fluids only when wait_station
  if event.contents then
    for item, _ in pairs(event.contents or {}) do
      result = result .. "[item=" .. item .. "] "
    end
  end
  if event.fluids then
    for fluid, _ in pairs(event.fluids or {}) do
      result = result .. "[fluid=" .. fluid .. "] "
    end
  end
  if result == "" then
    result = "no cargo"
  end
  return result
end

local function create_history_msg(event)
  local msg = { "", "Error" }
  local action = false
  local skip = false
  local style = ""
  local cargo = material_icon_list(event) or {}
  -- create material list
  if event.state == defines.train_state.wait_station and event.station and event.station.valid then
    msg = { "vtm.histstory-arrived", event.station.backer_name, cargo }
  elseif event.diff then
    msg = { "vtm.histstory-un-load", cargo }
  elseif event.state == defines.train_state.on_the_path then
    if event.old_tick then
      msg = { "vtm.histstory-waited", format.time(event.tick - event.old_tick--[[@as uint]] ) }
    else
      msg = { "vtm.histstory-done-waiting" }
    end
  elseif event.old_tick then
    msg = { "vtm.histstory-waited", format.time(event.tick - event.old_tick--[[@as uint]] ) }
  elseif event.state == defines.train_state.destination_full then
    msg = { "vtm.histstory-waiting" }
  elseif event.state == defines.train_state.wait_signal then
    msg = { "vtm.histstory-waiting" }
  else
    skip = true
    -- log(serpent.block(event))

  end

  return msg, style, action, skip
end

local function add_diff_to_shipment(shipment, event)
  if event.diff then
    for item, amount in pairs(event.diff.items or {}) do
      if amount < 0 then
        if shipment[item] then
          shipment[item].count = shipment[item].count + math.abs(amount)
        else
          shipment[item] = { type = "item", name = item, count = math.abs(amount), color = nil }
        end
      end
    end
    for item, amount in pairs(event.diff.fluids or {}) do
      if amount < 0 then
        if shipment[item] then
          shipment[item].count = shipment[item].count + math.abs(amount)
        else
          shipment[item] = { type = "fluid", name = item, count = math.abs(amount), color = nil }
        end
      end
    end
  end
end

local function update_route_flow(flow, history_data)
  local table_index = 0
  local children = flow.children
  local shipment = {}

  for _, event in pairs(history_data.events) do
    if event.schedule then
      return
    end
    table_index = table_index + 1
    -- get or create gui row
    local row = children[table_index]
    local msg, style, action, skip = create_history_msg(event)
    if skip then
      table_index = table_index - 1
      goto continue
    end
    add_diff_to_shipment(shipment, event)
    if not row then
      row = gui.add(flow, {
        type = "label",
        style = "vtm_semibold_label_with_padding",
      })
    end
    gui.update(row, { elem_mods = {
      caption = { "", msg },
    }
    })
    ::continue::
  end
  history_data.shipment = shipment
  for child_index = table_index + 1, #children do
    children[child_index].destroy()
  end
end

local function build_gui(gui_id)
  local width = constants.gui.history

  return {
    tab = {
      type = "tab",
      caption = { "vtm.tab-history" },
      ref = { "tabs", "history_tab" },
      name = "history",
      style_mods = { badge_horizontal_spacing = 6 },
      actions = {
        on_click = { type = "generic", action = "change_tab", tab = "history" },
      },
    },
    content = {
      type = "frame",
      style = "vtm_main_content_frame",
      direction = "vertical",
      ref = { "history", "content_frame" },
      -- table header
      {
        type = "frame",
        style = "subheader_frame",
        direction = "horizontal",
        style_mods = { horizontally_stretchable = true },
        {
          type = "label",
          style = "subheader_caption_label",
          caption = { "vtm.table-header-train-id" },
          style_mods = { width = width.train_id },
        },
        {
          type = "label",
          style = "subheader_caption_label",
          caption = { "vtm.table-header-route" },
          style_mods = { width = width.route },
        },
        {
          type = "label",
          style = "subheader_caption_label",
          caption = { "vtm.table-header-runtime" },
          style_mods = { width = width.runtime },
        },
        {
          type = "label",
          style = "subheader_caption_label",
          caption = { "vtm.table-header-finished" },
          style_mods = { width = width.finished },
        },
        {
          type = "label",
          style = "subheader_caption_label",
          caption = { "vtm.table-header-shipment" },
          style_mods = { width = width.shipment },
        },
        {
          type = "empty-widget",
          style = "flib_horizontal_pusher",
        },
        {
          type = "sprite-button",
          style = "tool_button_red",
          sprite = "utility/trash",
          tooltip = { "vtm.clear-history" },
          ref = { "history", "clear_button" },
          actions = {
            on_click = { type = "generic", action = "clear_history" },
          },
        },
      },
      {
        type = "scroll-pane",
        style = "vtm_table_scroll_pane",
        ref = { "history", "scroll_pane" },
        vertical_scroll_policy = "always",
        horizontal_scroll_policy = "auto",
      },
      {
        type = "frame",
        direction = "horizontal",
        style = "negative_subheader_frame",
        ref = { "history", "warning" },
        visible = true,
        {
          type = "flow",
          style = "centering_horizontal_flow",
          style_mods = { horizontally_stretchable = true },
          {
            type = "label",
            style = "bold_label",
            caption = { "", "[img=warning-white] ", { "vtm.no-history" } },
            ref = { "history", "warning_label" },
          },
        },
      },
    },
  }
end

local function update_tab(gui_id)
  local vtm_gui = global.guis[gui_id]
  local history = {}
  local max_hist = settings.global["vtm-history-length"].value
  local table_index = 0
  local filters = {
    -- item = vtm_gui.gui.filter.item.elem_value.name,
    -- fluid = vtm_gui.gui.filter.fluid.elem_value,
    search_field = vtm_gui.gui.filter.search_field.text:lower(),
  }

  local scroll_pane = vtm_gui.gui.history.scroll_pane
  local children = scroll_pane.children
  local width = constants.gui.history
  history = global.history
  -- filter
  for _, history_data in pairs(history) do
    if match.filter_history(history_data, filters) then

      if table_index >= max_hist then
        -- max entries
        goto continue
      end
      table_index = table_index + 1
      vtm_gui.gui.history.warning.visible = false
      -- get or create gui row
      local row = children[table_index]
      if not row then
        row = gui.add(scroll_pane, {
          type = "frame",
          direction = "horizontal",
          style = "vtm_table_row_frame",
          { -- train id
            type = "flow",
            style_mods = { horizontal_align = "center", width = width.train_id },
            {
              type = "sprite-button",
              style = "transparent_slot",
              sprite = "vtm_train",
              tooltip = { "vtm.train-removed" },
              {
                type = "label",
                style = "vtm_trainid_label",
              },
            }
          },
          { -- route
            type = "flow",
            direction = "vertical",
            name = "route",
            style_mods = { width = width.route },
          },
          { -- runtime
            type = "label",
            style = "vtm_semibold_label_with_padding",
            style_mods = { width = width.runtime, horizontal_align = "right" },
          },
          { -- finished
            type = "label",
            style = "vtm_semibold_label_with_padding",
            style_mods = { width = width.finished, horizontal_align = "right" },
          },
          gui_util.slot_table(width, "light", "shipment"),

        })
      end
      local prototype
      local sprite = "warning-white"
      local train_id = ""
      local tooltip = { "vtm.train-removed" }
      if history_data.train.valid then
        prototype = history_data.train.front_stock.prototype
        sprite = "item/" .. gui_util.signal_for_entity(history_data.train.front_stock).name
        train_id = history_data.train.id
        tooltip = prototype.localised_name
      end
      -- local runtime = format.time(history_data.last_change - history_data.started_at--[[@as uint]] )
      -- local finished = format.time(game.tick - history_data.last_change--[[@as uint]])
      local runtime = util.formattime(history_data.last_change - history_data.started_at--[[@as uint]] )
      local finished = util.formattime(game.tick - history_data.last_change--[[@as uint]] )

      gui.update(row, {
        { {
          elem_mods = {
            sprite = sprite,
            tooltip = tooltip,
          },
          {
            elem_mods = {
              caption = train_id
            },
            actions = {
              on_click = { type = "trains", action = "open-train", train_id = train_id },
            },
          },
          tooltip = { "", { "gui-trains.open-train" }, " Train ID: ", train_id },
        } },
        { -- route, gets updated below
        },
        { -- runtime
          elem_mods = { caption = runtime },
        },
        { -- finished
          elem_mods = { caption = finished },
        },
      })
      update_route_flow(row.route, history_data)
      gui_util.slot_table_update(row.shipment_table, history_data.shipment, vtm_gui.gui_id)

    end
  end
  ::continue::
  scroll_pane.scroll_to_top()
  vtm_gui.gui.tabs.history_tab.badge_text = table_index
  if table_index == 0 then
    vtm_gui.gui.history.warning.visible = true
  end
  for child_index = table_index + 1, #children do
    children[child_index].destroy()
  end
end

return {
  build_gui = build_gui,
  update_tab = update_tab,
  -- handle_action = handle_action,
}
