-- history.lua
local util        = require("__core__.lualib.util")
local flib_gui    = require("__flib__.gui")
local flib_table  = require("__flib__.table")
local flib_format = require("__flib__.format")
local gui_utils   = require("__virtm__.scripts.gui.utils")
local match       = require("__virtm__.scripts.match")
local constants   = require("__virtm__.scripts.constants")
local backend     = require("__virtm__.scripts.backend")
local searchbar    = require("__virtm__.scripts.gui.searchbar")

local history     = {}
local function material_icon_list(event)
  local result = ""
  local zero = 0
  -- diff only after leaving station
  if event.diff then
    for _, item in pairs(event.diff.items or {}) do
      result = result ..
          util.format_number(item.count, true) .. " [item=" .. item.name .. ",quality=" .. item.quality .. "], "
      zero = zero + item.count
    end
    for name, count in pairs(event.diff.fluids or {}) do
      result = result .. util.format_number(math.ceil(count), true) .. " [fluid=" .. name .. "], "
      zero = zero + count
    end
  end
  --contents and fluids only when wait_station
  if event.contents then
    for _, item in pairs(event.contents or {}) do
      result = result .. "[item=" .. item.name .. ",quality=" .. item.quality .. "] "
    end
  end
  if event.fluids then
    for name, _ in pairs(event.fluids or {}) do
      result = result .. "[fluid=" .. name .. "] "
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
      local station_data = storage.stations[event.station.unit_number]
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
      msg = { "vtm.histstory-waited", flib_format.time(event.tick - event.old_tick --[[@as uint]]) }
      if compact then skip = true end
    else
      msg = { "vtm.histstory-done-waiting" }
      if compact then skip = true end
    end
  elseif event.old_tick then
    msg = { "vtm.histstory-waited", flib_format.time(event.tick - event.old_tick --[[@as uint]]) }
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
    for _, item in pairs(event.diff.items or {}) do
      local key = item.name .. item.quality
      if item.count < 0 then
        if shipment[key] then
          shipment[key].count = shipment[key].count + math.abs(item.count)
        else
          shipment[key] = { type = "item", name = item.name, count = math.abs(item.count), quality = item.quality }
        end
      end
    end
    for fluid, count in pairs(event.diff.fluids or {}) do
      local key = fluid
      if count < 0 then
        if shipment[key] then
          shipment[key].count = shipment[key].count + math.abs(count)
        else
          shipment[key] = { type = "fluid", name = fluid, count = math.abs(count) }
        end
      end
    end
  end
end

-- --- @param gui_data GuiData
-- --- @param event EventData|EventData.on_gui_click
-- function history.show_station(gui_data, event)
--   gui_utils.show_station(gui_data, event)
-- end

--- @param gui_data GuiData
--- @param event EventData|EventData.on_gui_click
function history.open_train(gui_data, event)
  gui_utils.open_train(gui_data, event)
end

local function update_route_flow(flow, history_data, compact)
  local table_index = 0
  local children = flow.children
  local shipment = {} --[[@as SlotTableDef[] ]]

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
        refs, row = flib_gui.add(flow, {
          type = "label",
          style = "vtm_semibold_label_with_padding",
        })
      end
      row.caption = { "", msg }
    end
  end
  history_data.shipment = shipment
  for child_index = table_index + 1, #children do
    children[child_index].destroy()
  end
end

function history.build_tab()
  local width = constants.gui.history
  return {
    tab = {
      type = "tab",
      caption = { "vtm.tab-history" },
      name = "history",
      style_mods = { badge_horizontal_spacing = 6 },
    },
    content = {
      type = "frame",
      name = "history_content_frame",
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
            name = "history_switch",
            style = "vtm_subheader_switch",
            left_label_caption = { "vtm.table-header-compact" },
            right_label_caption = { "vtm.table-header-detail" },
            left_label_tooltip = { "vtm.table-header-compact-tooltip" },
            allow_none_state = false,
            switch_state = "right",
            handler = { [defines.events.on_gui_switch_state_changed] = history.history_switch },
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
          name = "history_clear_button",
          style = "tool_button_red",
          sprite = "utility/trash",
          tooltip = { "vtm.clear-history" },
          handler = { [defines.events.on_gui_click] = history.clear_history },
        },
      },
      {
        type = "scroll-pane",
        name = "history_scrollpane",
        style = "vtm_table_scroll_pane",
        vertical_scroll_policy = "always",
        horizontal_scroll_policy = "auto",
      },
      {
        type = "frame",
        direction = "horizontal",
        style = "negative_subheader_frame",
        name = "history_warning",
        visible = true,
        {
          type = "flow",
          style = "compact_horizontal_flow",
          style_mods = { horizontally_stretchable = true },
          {
            type = "label",
            style = "bold_label",
            caption = { "", "[img=warning-white] ", { "vtm.no-history" } },
            name = "history_warning_label",
          },
        },
      },
    },
  }
end

function history.update_tab(gui_data, event)
  local player = gui_data.player
  local surface = storage.settings[player.index].surface or "All"
  local history_datas = {}
  local max_hist = storage.max_hist
  local table_index = 0
  local filters = { search_field = gui_data.gui.search_field.text:lower() }

  local switch_state = storage.settings[player.index].history_switch or "left"
  local compact = switch_state == "left" or false

  gui_data.gui.history_switch.switch_state = switch_state

  -- filter
  for _, history_data in pairs(storage.history) do
    if history_data.force_index == gui_data.player.force.index and
        (surface == "All" or surface == history_data.surface) and
        table_size(history_data.events) > 2 and
        match.filter_history(history_data, filters)
    then
      table.insert(history_datas, history_data)
    end
  end

  -- finish when not current tab
  if storage.settings[gui_data.player.index].current_tab ~= "history" then
    gui_data.gui.history.badge_text = table_size(history_datas)
    return
  end
  local scroll_pane = gui_data.gui.history_scrollpane or {}
  local children = scroll_pane.children
  local width = constants.gui.history

  for _, history_data in pairs(history_datas) do
    if table_index >= max_hist then
      -- max entries
      break
    end
    table_index = table_index + 1
    gui_data.gui.history_warning.visible = false
    -- get or create gui row
    local row = children[table_index]
    local refs = {}
    if not row then
      local gui_contents = {
        type = "frame",
        direction = "horizontal",
        style = "vtm_table_row_frame",
        {
          -- train id
          type = "flow",
          style_mods = { horizontal_align = "center", width = width.train_id },
          {
            type = "sprite",
            name = "history_sprite",
            sprite = "utility/side_menu_train_icon",
            tooltip = { "vtm.train-removed" },
            {
              type = "label",
              name = "history_train_id",
              style = "vtm_trainid_label",
              handler = { [defines.events.on_gui_click] = history.open_train }
            },
          }
        },
        {
          -- route
          type = "flow",
          direction = "vertical",
          name = "history_route",
          style_mods = { width = width.route },
        },
        {
          -- runtime
          type = "label",
          name = "history_runtime",
          style = "vtm_semibold_label_with_padding",
          style_mods = { width = width.runtime, horizontal_align = "right" },
        },
        {
          -- finished
          type = "label",
          name = "history_finished",
          style = "vtm_semibold_label_with_padding",
          style_mods = { width = width.finished, horizontal_align = "right" },
        },
        gui_utils.slot_table(width, nil, "shipment"),
      }
      refs, row = flib_gui.add(scroll_pane, gui_contents)
    end

    local prototype
    local sprite = "warning-white"
    local train_id_str = ""
    ---@type LocalisedString
    local tooltip = { "vtm.train-removed" }

    if history_data.train.valid then
      prototype = history_data.prototype
      sprite = history_data.sprite
      train_id_str = tostring(history_data.train.id)
      tooltip = prototype.localised_name
    elseif history_data.surface2 and helpers.is_valid_sprite_path("item/se-space-elevator") then
      sprite = "item/se-space-elevator"
    end

    -- local runtime = util.formattime(history_data.last_change - history_data.started_at --[[@as uint]])
    local runtime = flib_format.time(history_data.last_change - history_data.started_at --[[@as uint]])
    -- local finished = util.formattime(game.tick - history_data.last_change --[[@as uint]])
    local finished = flib_format.time(game.tick - history_data.last_change --[[@as uint]])
    if table_size(refs) == 0 then
      refs = gui_utils.recreate_gui_refs(row)
    end
    refs.history_sprite.sprite = sprite
    refs.history_sprite.tooltip = tooltip
    refs.history_train_id.caption = train_id_str
    refs.history_train_id.tooltip = { "", { "gui-trains.open-train" }, " Train ID: ", train_id_str }
    refs.history_runtime.caption = runtime
    refs.history_finished.caption = finished
    if history_data.train.valid then
      refs.history_train_id.tags = flib_table.shallow_merge({ refs.history_train_id.tags, { train_id = history_data.train.id } })
    end
    update_route_flow(refs.history_route, history_data, compact)
    -- Light Running, hide empty row in comact mode (most likely, interrupt disturbs the schedule)
    row.visible = true
    if #refs.history_route.children == 0 then
      row.visible = false
    end
    gui_utils.slot_table_update(row.shipment_table, history_data.shipment, searchbar.apply_filter)
  end

  scroll_pane.scroll_to_top()
  gui_data.gui.history.badge_text = table_index
  if table_index == 0 then
    gui_data.gui.history_warning.visible = true
  end

  for child_index = table_index + 1, #children do
    children[child_index].destroy()
  end
end

local function refresh(gui_data, event)
  script.raise_event(constants.refresh_event, {
    player_index = gui_data.player.index,
  })
end

function history.clear_history(gui_data, event)
  -- delete history older 2 mins
  local older_than = game.tick - gui_utils.ticks(1)
  backend.clear_older(event.player_index, older_than)
  refresh(gui_data, event)
end

function history.history_switch(gui_data, event)
  storage.settings[event.player_index].history_switch = event.element.switch_state
  refresh(gui_data, event)
end

flib_gui.add_handlers(history, function(event, handler)
  local gui_id = gui_utils.get_gui_id(event.player_index)
  ---@type GuiData
  local gui_data = storage.guis[gui_id]
  if gui_data then
    handler(gui_data, event)
  end
end, "history")

return history
