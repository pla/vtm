-- history.lua
local util = require("__core__.lualib.util")
local gui = require("__flib__.gui")
local gui_util = require("__vtm__.scripts.gui.utils")
local match = require("__vtm__.scripts.match")
local constants = require("__vtm__.scripts.constants")
local format = require("__flib__.format")

local function material_icon_list(event)
  local result = ""
  local zero = 0
  -- diff only after leaving station
  if event.diff then
    for item, amount in pairs(event.diff.items or {}) do
      result = result .. util.format_number(amount, "k") .. " [item=" .. item .. "], "
      zero = zero + amount
    end
    for fluid, amount in pairs(event.diff.fluids or {}) do
      result = result .. util.format_number(math.ceil(amount), "k") .. " [fluid=" .. fluid .. "], "
      zero = zero + amount
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
  return result, zero == 0
end

local function create_history_msg(event, compact)
  local msg = { "", "Error" }
  local action = false
  local skip = false
  local style = ""
  local cargo, is_zero = material_icon_list(event)

  -- create material list
  if event.state == defines.train_state.wait_station and event.station and event.station.valid then
    msg = { "vtm.histstory-arrived", event.station.backer_name, cargo }
    if compact then
      local station_data = global.stations[event.station.unit_number]
      skip = station_data.type == "D" or station_data.type == "F"
    end
  elseif event.diff then
    msg = { "vtm.histstory-un-load", cargo }
    -- if compact then skip = is_zero end
    if compact then skip = true end
  elseif event.se_elevator then
    msg = { "vtm.histstory-se-elevator-leave" }
    if compact then skip = true end
  elseif event.state == defines.train_state.on_the_path then
    if event.old_tick then
      msg = { "vtm.histstory-waited", format.time(event.tick - event.old_tick --[[@as uint]]) }
      if compact then skip = true end
    else
      msg = { "vtm.histstory-done-waiting" }
      if compact then skip = true end
    end
  elseif event.old_tick then
    msg = { "vtm.histstory-waited", format.time(event.tick - event.old_tick --[[@as uint]]) }
    if compact then skip = true end
  elseif event.state == defines.train_state.destination_full then
    msg = { "vtm.histstory-waiting" }
    if compact then skip = true end
  elseif event.state == defines.train_state.wait_signal then
    msg = { "vtm.histstory-waiting" }
    if compact then skip = true end
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

local function update_route_flow(flow, history_data, compact)
  local table_index = 0
  local children = flow.children
  local shipment = {}

  for _, event in pairs(history_data.events) do
    if event.schedule then -- schedule changend event
      return
    end
    local msg, style, action, skip = create_history_msg(event, compact)
    add_diff_to_shipment(shipment, event)
    if not skip then
      table_index = table_index + 1
      -- get or create gui row
      local row = children[table_index]
      if not row then
        row = gui.add(flow, {
          type = "label",
          style = "vtm_semibold_label_with_padding",
        })
      end
      gui.update(row, {
        elem_mods = {
          caption = { "", msg },
        }
      })
    end
  end
  history_data.shipment = shipment
  for child_index = table_index + 1, #children do
    children[child_index].destroy()
  end
end

local function build_gui()
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
          type = "flow",
          style_mods = { width = width.route, vertical_align = "center" },
          {
            type = "label",
            style = "subheader_caption_label",
            caption = { "vtm.table-header-route" },
            style_mods = { maximal_width = width.route - width.switch },
          },
          {
            type = "empty-widget",
            style = "flib_horizontal_pusher",
          },
          {
            type = "switch",
            ref = { "history", "switch" },
            style = "vtm_subheader_switch",
            left_label_caption = { "vtm.table-header-compact" },
            right_label_caption = { "vtm.table-header-detail" },
            right_label_tooltip = { "vtm.table-header-detail-tooltip" },
            allow_none_state = false,
            switch_state = "right",
            actions = {
              on_switch_state_changed = { type = "generic", action = "history_switch" },
            },
          },
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
          style_mods = { width = width.shipment + 100 },
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
  local player = global.guis[gui_id].player
  local vsettings = global.settings[player.index]
  local surface = vsettings.surface or "All"
  local history = {}
  local max_hist = settings.global["vtm-history-length"].value
  local table_index = 0
  local filters = { search_field = vtm_gui.gui.filter.search_field.text:lower() }

  local switch_state = vsettings.history_switch or "left"
  local compact = switch_state == "left" or false
  local scroll_pane = vtm_gui.gui.history.scroll_pane or {}
  local children = scroll_pane.children
  local width = constants.gui.history

  vtm_gui.gui.history.switch.switch_state = switch_state
  history = global.history

  -- filter
  for _, history_data in pairs(history) do
    if history_data.force_index == vtm_gui.player.force.index and
        (surface == "All" or surface == history_data.surface) and
        table_size(history_data.events) > 2 and
        match.filter_history(history_data, filters)
    then
      if table_index >= max_hist then
        -- max entries
        break
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
          {
            -- train id
            type = "flow",
            style_mods = { horizontal_align = "center", width = width.train_id },
            {
              type = "sprite-button",
              style = "transparent_slot",
              sprite = "utility/side_menu_train_icon",
              tooltip = { "vtm.train-removed" },
              {
                type = "label",
                style = "vtm_trainid_label",
              },
            }
          },
          {
            -- route
            type = "flow",
            direction = "vertical",
            name = "route",
            style_mods = { width = width.route },
          },
          {
            -- runtime
            type = "label",
            style = "vtm_semibold_label_with_padding",
            style_mods = { width = width.runtime, horizontal_align = "right" },
          },
          {
            -- finished
            type = "label",
            style = "vtm_semibold_label_with_padding",
            style_mods = { width = width.finished, horizontal_align = "right" },
          },
          gui_util.slot_table(width, nil, "shipment"),
        })
      end

      local prototype
      local sprite = "warning-white"
      local train_id = ""
      ---@type LocalisedString
      local tooltip = { "vtm.train-removed" }

      if history_data.train.valid then
        prototype = history_data.prototype
        sprite = history_data.sprite
        train_id = tostring(history_data.train.id)
        tooltip = prototype.localised_name
      elseif history_data.surface2 and game.is_valid_sprite_path("item/se-space-elevator") then
        sprite = "item/se-space-elevator"
      end

      -- local runtime = util.formattime(history_data.last_change - history_data.started_at --[[@as uint]])
      local runtime = format.time(history_data.last_change - history_data.started_at --[[@as uint]])
      -- local finished = util.formattime(game.tick - history_data.last_change --[[@as uint]])
      local finished = format.time(game.tick - history_data.last_change --[[@as uint]])

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
      update_route_flow(row.route, history_data, compact)
      gui_util.slot_table_update(row.shipment_table, history_data.shipment, vtm_gui.gui_id)
    end
  end

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
