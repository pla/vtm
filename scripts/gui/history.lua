-- history.lua
local gui = require("__flib__.gui")
local gui_util = require("scripts.gui.util")
local match = require("scripts.match")
local constants = require("scripts.constants")

local function material_icon_list(event)
  local result = ""
  -- diff only after leaving station
  if event.diff then
    for item, _ in pairs(event.diff.items or {}) do
      result = result .. "[item=" .. item .. "]"
    end
    for item, _ in pairs(event.diff.fluids or {}) do
      result = result .. "[fluid=" .. item .. "]"

    end
  end
  --contents and fluids only when wait_station
  if event.contents then
    for item, _ in pairs(event.contents or {}) do
      result = result .. "[item=" .. item .. "]"
    end
  end
  if event.fluids then
    for item, _ in pairs(event.fluids or {}) do
      result = result .. "[fluid=" .. item .. "]"

    end
  end
  if result == "" then
    result = "no cargo"
  end
  return result
end

local function create_history_msg(event)
  local msg = { "", "Error" }
  local style = "vtm_semibold_label"
  local action = false
  local style_click = "vtm_clickable_semibold_label"
  local cargo = material_icon_list(event) or {}
  -- create material list
  if event.state == defines.train_state.wait_station then
    style = style_click
    msg = { "vtm.histstory-arrived", event.station.backer_name, cargo }
  elseif event.diff then
    style = style
    msg = { "vtm.histstory-un-load", cargo }
  elseif event.old_tick then
    msg = { "vtm.histstory-waited", event.tick - event.old_tick }
  elseif event.state == defines.train_state.on_the_path then
    msg = { "vtm.histstory-done-waiting" }

  elseif event.state == defines.train_state.destination_full then
    msg = { "vtm.histstory-waiting" }

  end

  return msg, style, action
end

local function update_route_flow(flow, history_data)
  local table_index = 0
  local children = flow.children

  for _, event in pairs(history_data.events) do
    if event.schedule then
      return
    end
    table_index = table_index + 1
    -- get or create gui row
    local row = children[table_index]
    local color = table_index % 2 == 0 and "dark" or "light"
    local msg, style, action = create_history_msg(event)
    if not row then
      row = gui.add(flow, {
        type = "label",
        style = "vtm_semibold_label",
      })
    end
    gui.update(row, { elem_mods = {
      caption = { "", msg },
      -- style = style, -- FIXME: padding is different

    }
    })
  end
  for child_index = table_index + 1, #children do
    children[child_index].destroy()
  end
end

local function build_gui(gui_id)
  -- local vtm_gui = global.guis[gui_id]
  -- local tabs = vtm_gui.gui.tabs
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
          style_mods = { width = width.route, horizontally_stretchable = true },
        },
        -- {
        --   type = "empty-widget",
        --   style = "flib_horizontal_pusher",
        -- },
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
          style_mods = { width = width.finished, horizontally_stretchable = true },
        },
        {
          type = "label",
          style = "subheader_caption_label",
          caption = { "vtm.table-header-shipment" },
          style_mods = { width = width.shipment },
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
        -- style_mods = { vertically_stretchable = true },
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
    item = vtm_gui.gui.filter.item.elem_value,
    fluid = vtm_gui.gui.filter.fluid.elem_value,
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
      -- get or create gui row
      local row = children[table_index]
      local color = table_index % 2 == 0 and "dark" or "light"
      if not row then
        row = gui.add(scroll_pane, {
          type = "frame",
          direction = "horizontal",
          style = "vtm_table_row_frame",
          -- style = "vtm_table_row_frame_" .. color,
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
            -- style_mods = { horizontally_stretchable = true },

          },
          {
            type = "label",
            style = "vtm_clickable_semibold_label",
            style_mods = { width = width.runtime },
          },
          {
            type = "label",
            style = "vtm_clickable_semibold_label",
            style_mods = { width = width.finished },
          },

        })
      end
      local prototype = history_data.train.front_stock.prototype
      local runtime = gui_util.ticks_to_timestring(history_data.last_change - history_data.started_at)
      local finished = gui_util.ticks_to_timestring(game.tick - history_data.last_change)

      gui.update(row, {
        { {
          elem_mods = {
            sprite = "item/" .. gui_util.signal_for_entity(history_data.train.front_stock).name,
            tooltip = prototype.localised_name,
          },
          actions = {
            on_click = { type = "trains", action = "open-train", train_id = history_data.train.id },

          },
          {
            elem_mods = {
              caption = tostring(history_data.train.id)
            }
          },
        } },
        { -- route
        },

        { -- runtime
          elem_mods = { caption = runtime },
        },
        { -- finished
          elem_mods = { caption = finished },
        },
      })
      update_route_flow(row.route, history_data)
    end
  end
  ::continue::
  scroll_pane.scroll_to_top()
  if table_index > 0 then
    vtm_gui.gui.tabs.history_tab.badge_text = table_index
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
