local flib_train = require("__flib__.train")
local tables     = require("__flib__.table")
local flib_gui   = require("__flib__.gui")
local gui_utils  = require("__virtm__.scripts.gui.utils")
local constants  = require("__virtm__.scripts.constants")
local match      = require("__virtm__.scripts.match")
local format     = require("__flib__.format")


local inv_states = tables.invert(defines.train_state)

local trains = {}

local function select_station_from_eventlist(list, last)
  local station = nil
  local size = table_size(list)
  if last or size == 1 then
    station = list[size].station or nil
  else
    if size > 2 then
      station = list[size - 1].station or nil
    end
  end
  return station
end

local function select_station_from_schedule(train)
  local schedule = train.schedule
  if schedule ~= nil then
    local station = schedule.records[schedule.current].station
    if station == nil and schedule.records[schedule.current].rail ~= nil then --cybersyn method
      --if the rail connected to a station?
      local front = schedule.records[schedule.current].rail.get_rail_segment_stop(defines.rail_direction.front)
      local back = schedule.records[schedule.current].rail.get_rail_segment_stop(defines.rail_direction.back)
      if front and front.type == "train-stop" then
        station = front.backer_name
      end
      if back and back.type == "train-stop" then
        station = back.backer_name
      end
    end
    if station == nil and schedule.records[schedule.current].temporary then
      local position = "Position (" .. train.carriages[1].position.x .. ", " .. train.carriages[1].position.y .. ")"
      return position
    end
    if station == nil then
      local position = "Position (" .. train.carriages[1].position.x .. ", " .. train.carriages[1].position.y .. ")"
      return position
    end
    return station
  else
    return { "vtm.unclear" }
  end
end

local function train_status_message(train_data)
  local msg = { "vtm.train-msg-error" }
  if not train_data.train.valid then
    return msg
  end
  local def_state = defines.train_state
  local train = train_data.train
  local desc = constants.state_description
  local state = train.state
  local distance = tostring("42")
  if train.has_path and train.path.valid then
    distance = tostring(math.ceil(train.path.total_distance - train.path.travelled_distance))
  end
  if state == def_state.on_the_path or
      state == def_state.arrive_signal or
      state == def_state.wait_signal or
      state == def_state.arrive_station
  then
    if train.path_end_stop ~= nil then
      msg = { desc[train.state], train.path_end_stop.backer_name, distance }
    else
      local station = nil
      station = select_station_from_schedule(train)
      if station ~= nil then
        msg = { desc[train.state], station, distance }
      end
    end
  elseif state == def_state.wait_station then
    if train.station ~= nil then
      msg = { desc[train.state], train.station.backer_name }
    else
      -- Temp Stop
      local station = nil
      station = select_station_from_schedule(train)
      if station ~= nil then
        msg = { desc[train.state], station, distance }
      end
    end
  elseif train.state == def_state.destination_full then
    if train.station then
      local station = train.station
      if station ~= nil then
        if next(train_data.contents.items) or next(train_data.contents.fluids) then
          msg = { "vtm.train-state-destination-full-cargo", station.backer_name }
        else
          msg = { "vtm.train-state-destination-full-empty", station.backer_name }
        end
      else
        station = select_station_from_schedule(train)
        msg = { "vtm.destination-full", station }
      end
    end
  elseif state == def_state.manual_control_stop then
    msg = { "gui-train-state.manually-stopped" }
  elseif state == def_state.manual_control then
    msg = { "gui-train-state.manually-driving" }
  elseif state == def_state.no_path then
    msg = { "gui-train-state.no-path-to", select_station_from_schedule(train) }
  elseif state == def_state.no_schedule then
    msg = { "gui-train-state.no-schedule" }
  else
    -- default message for unhandled states
    msg = { "", inv_states[train.state], " : ", train.state }
  end


  return msg
end

--- @param gui_data GuiData
--- @param event? EventData|EventData.on_gui_click
function trains.update_trains_tab(gui_data, event)
  local surface = storage.settings[gui_data.player.index].surface or "All"
  ---@type table<uint,TrainData>
  local train_datas = {}
  local inv_trains = {}
  local table_index = 0
  local max_lines = storage.max_lines
  local filters = {
    search_field = gui_data.gui.search_field.text:lower(),
  }

  -- select trains from global
  for train_id, train_data in pairs(storage.trains) do
    if not train_data.train.valid then
      table.insert(inv_trains, train_id)
    end
    if train_data.force_index == gui_data.player.force.index and
        train_data.train.valid and
        (surface == "All" or surface == train_data.train.carriages[1].surface.name)
    then
      if match.filter_trains(train_data, filters) then
        table.insert(train_datas, train_data)
      end
    end
  end
  -- delete invalid traindata
  for _, train_id in pairs(inv_trains) do
    storage.trains[train_id] = nil
  end

  table.sort(train_datas, function(a, b) return a.last_change > b.last_change end)

  local scroll_pane = gui_data.gui.trains_scrollpane
  local children = scroll_pane.children
  local width = constants.gui.trains

  if storage.settings[gui_data.player.index].current_tab ~= "trains" then
    gui_data.gui.trains.badge_text = table_size(train_datas)
    return
  end

  for _, train_data in pairs(train_datas) do
    if train_data.train.valid then
      if table_index >= max_lines and
          max_lines > 0 and
          storage.settings[gui_data.player.index].gui_refresh == "auto" and
          filters.search_field == ""
      then
        -- max entries
        break
      end

      table_index = table_index + 1
      gui_data.gui.trains_warning.visible = false
      -- get or create gui row
      local row = children[table_index]
      local refs = {}
      if not row then
        local gui_contents = {
          type = "frame",
          -- name = "row_frame",
          direction = "horizontal",
          style = "vtm_table_row_frame",
          {
            -- train id
            type = "flow",
            style_mods = { horizontal_align = "center", width = width.train_id },
            {
              type = "sprite",
              name = "train_sprite",
              sprite = "utility/side_menu_train_icon",
              tooltip = { "vtm.train-removed" },
              {
                type = "label",
                name = "train_id",
                style = "vtm_trainid_label",
                handler = { [defines.events.on_gui_click] = trains.open_train }
              },
            },
          },
          {
            type = "label",
            name = "status",
            style = "vtm_semibold_label_with_padding",
            style_mods = { width = width.status },
          },
          {
            type = "label",
            name = "since",
            style = "vtm_semibold_label_with_padding",
            style_mods = { width = width.since, horizontal_align = "center" },
          },
          {
            type = "label",
            name = "composition",
            style = "vtm_semibold_label_with_padding",
            style_mods = { width = width.composition },
          },
          gui_utils.slot_table(width, nil, "cargo"),
        }
        refs, row = flib_gui.add(scroll_pane, gui_contents)
      end
      -- create refs for existing row
      if table_size(refs) == 0 then
        refs = gui_utils.recreate_gui_refs(row)
      end
      local status_string = train_status_message(train_data)
      local since = format.time(game.tick - train_data.last_change --[[@as uint]])
      -- Fill with data
      refs.train_sprite.sprite = train_data.sprite
      refs.train_id.caption = train_data.train.id
      refs.train_id.tooltip = { "vtm.train-open-ui-follow-train", train_data.train.id }
      refs.train_id.tags = { train_id = train_data.train.id }
      refs.status.caption = status_string
      refs.status.tooltip = { "", inv_states[train_data.train.state], " : ", train_data.train.state }
      refs.since.caption = since
      refs.composition.caption = train_data.composition

      gui_utils.slot_table_update_train(row.cargo_table, train_data.contents)
    end
  end
  gui_data.gui.trains.badge_text = table_index
  if table_index == 0 then
    gui_data.gui.trains_warning.visible = true
  end
  for child_index = table_index + 1, #children do
    children[child_index].destroy() -- TODO change to visible
  end
end

function trains.build_trains_tab()
  local width = constants.gui.trains
  return {
    tab = {
      type = "tab",
      caption = { "gui-trains.trains-tab" },
      name = "trains",
      style_mods = { badge_horizontal_spacing = 6 },
    },
    content = {
      type = "frame",
      name = "trains_content_frame",
      style = "vtm_main_content_frame",
      direction = "vertical",
      -- table header
      {
        type = "frame",
        style = "subheader_frame",
        direction = "horizontal",
        style_mods = { horizontally_stretchable = true },
        children = {
          {
            type = "label",
            style = "subheader_caption_label",
            caption = { "vtm.table-header-train-id" },
            style_mods = { width = width.train_id },
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
            caption = { "vtm.table-header-composition" },
            style_mods = { width = width.composition },
          },
          {
            type = "label",
            style = "subheader_caption_label",
            caption = { "vtm.table-header-cargo" },
            style_mods = { width = width.cargo },
          },
        }
      },
      { -- scroll pane for the actual traindata, data will be filled in by the update gui function
        type = "scroll-pane",
        name = "trains_scrollpane",
        style = "vtm_table_scroll_pane",
        vertical_scroll_policy = "always",
        horizontal_scroll_policy = "never",
      },
      { -- warning no train here
        type = "frame",
        name = "trains_warning",
        direction = "horizontal",
        style = "negative_subheader_frame",
        visible = true,
        {
          type = "flow",
          style = "compact_horizontal_flow",
          style_mods = { horizontally_stretchable = true },
          {
            type = "label",
            style = "bold_label",
            caption = { "", "[img=warning-white] ", { "gui-trains.no-trains" } },
            ref = { "trains", "warning_label" },
          },
        },
      },
    }
  }
end

--- @param gui_data GuiData
--- @param event EventData|EventData.on_gui_click
function trains.open_train(gui_data, event)
  local train_id
  if event.element.tags and event.element.tags.train_id then
    train_id = event.element.tags.train_id
  else
    return
  end
  if storage.trains[tonumber(train_id)] then
    local train = storage.trains[tonumber(train_id)].train
    if not train.valid then return end
    local loco = flib_train.get_main_locomotive(train)
    local player = gui_data.player
    if event.shift and loco and loco.valid then
      -- follow train in map/remote view
      player.centered_on = loco
    else
      if loco and loco.valid then
        gui_utils.open_entity_gui(event.player_index, loco)
      end
    end
  end
end

-- ---Handle gui actions
-- ---@param action GuiAction
-- ---@param event EventData.on_gui_click
-- function trains.handle_action(action, event)
--   if action.action == "open-train" then
--     if storage.trains[tonumber(action.train_id)] then
--       local train = storage.trains[tonumber(action.train_id)].train
--       if not train.valid then return end
--       local loco = flib_train.get_main_locomotive(train)
--       local player = game.players[event.player_index]
--       if event.shift and loco and loco.valid then
--         -- follow train in map/remote view
--         player.centered_on = loco
--       else
--         if loco and loco.valid then
--           gui_util.open_entity_gui(event.player_index, loco)
--         end
--       end
--     end
--   elseif action.action == "refresh" then
--     trains.update_tab(action.gui_id)
--   end
-- end

flib_gui.add_handlers(trains, function(event, handler)
  local gui_id = gui_utils.get_gui_id(event.player_index)
  ---@type GuiData
  local gui_data = storage.guis[gui_id]
  if gui_data then
    handler(gui_data, event)
  end
end)

return trains
