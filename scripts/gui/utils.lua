-- gui/util.lua
local gui = require("__flib__.gui")

local util = {}

function util.get_gui_id(player_index)
  local player = game.get_player(player_index)
  for gui_id, vtm_gui in pairs(global.guis) do
    if vtm_gui.player == player then
      return gui_id
    end
  end
  return nil
end

function util.read_inbound_trains(station_data)
  local station = station_data.station
  local contents = {}
  local inv_trains={}
  if station.valid and station_data.incoming_trains then
    local trains = station_data.incoming_trains
    for train_id, _ in pairs(trains) do
      local train_data = global.trains[train_id]
      if train_data and train_data.train.valid then
        if train_data.path_end_stop == station.unit_number then
          for type, item_data in pairs(train_data.contents) do
            local row = {}
            row.type = type == "items" and "item" or "fluid"
            for name, count in pairs(item_data) do
              row.name = name
              row.count = count
              row.color =  "blue"
              table.insert(contents, row)
            end
          end
        end
      else
        table.insert(inv_trains,train_id)
      end
    end
    -- delete invalid traindata
    for _, train_id in pairs(inv_trains) do
      global.trains[train_id]=nil
      station_data.incoming_trains[train_id]=nil
    end
  end
  return contents
end

--- Creates a non-scrollable slot table.
--- @param widths table
--- @param color? string
--- @param name string
function util.slot_table(widths, color, name)
  return {
    type = "table",
    name = name .. "_table",
    style = "slot_table",
    style_mods = {
      width = widths[name],
      minimal_height = 36,
      -- horizontal_spacing = 4,
      -- vertical_spacing = 4,
      cell_padding = 2,
      left_padding = 8,
    },
    column_count = widths[name .. "_columns"]
  }
end

--- A dataset to put into a slot table.
---
--- @class SlotTableDef
--- @field type string
--- @field name string
--- @field count number
--- @field color string

--- Updates a slot table based on the passed criteria.
--- @param icon_table LuaGuiElement
--- @param sources SlotTableDef[]
--- @param gui_id string
function util.slot_table_update(icon_table, sources, gui_id)
  local children = icon_table.children
  local i = 0
  for _, source_data in pairs(sources) do
    i = i + 1
    local button = children[i]
    if not button then

      button = gui.add(icon_table, { type = "sprite-button" })

    end
    util.update_sprite_button(
      button,
      source_data.type,
      source_data.name,
      source_data.count,
      source_data.color or nil,
      gui_id
    )
    -- button.enabled = false
  end

  for i = i + 1, #children do
    children[i].destroy()
  end
end

function util.sprite_button_type_name_amount(type, name, amount, color, gui_id)
  local prototype = nil
  if type == "item" then
    prototype = game.item_prototypes[name]
  elseif type == "fluid" then
    prototype = game.fluid_prototypes[name]
  elseif type == "virtual-signal" then
    prototype = game.virtual_signal_prototypes[name]
  end
  local sprite, tooltip, style
  if prototype then
    sprite = type .. "/" .. name
    if color ~= nil and (color == "red" or color == "green") then
      local color_item = game.item_prototypes[color .. "-wire"]
      tooltip = { "", prototype.localised_name, ", ", color_item.localised_name }
    else
      tooltip = prototype.localised_name
    end
    style = "transparent_slot"
  else
    tooltip = "Error"
    sprite = "warning-white"
    style = "flib_tool_button_dark_red"
  end
  return {
    type = "sprite-button",
    style = style,
    sprite = sprite,
    number = amount,
    actions = {
      on_click = { type = "searchbar", action = "filter", filter = type, value = name, gui_id = gui_id }
    },
    tooltip = tooltip
  }
end

function util.update_sprite_button(button, type, name, amount, color, gui_id)
  local prototype = nil
  if type == "item" then
    prototype = game.item_prototypes[name]
  elseif type == "fluid" then
    prototype = game.fluid_prototypes[name]
  elseif type == "virtual-signal" then
    prototype = game.virtual_signal_prototypes[name]
  end
  local sprite, tooltip, style
  if prototype then
    sprite = type .. "/" .. name
    if color ~= nil and (color == "red" or color == "green") then
      local color_item = game.item_prototypes[color .. "-wire"]
      tooltip = { "", prototype.localised_name, ", ", color_item.localised_name }
    else
      tooltip = prototype.localised_name
    end
    style = "transparent_slot"
  else
    tooltip = "Error"
    sprite = "warning-white"
    style = "flib_tool_button_dark_red"
  end
  gui.update(button, {
    elem_mods = {
      style = style,
      sprite = sprite,
      number = amount,
      tooltip = tooltip,
    },
    actions = {
      on_click = { type = "searchbar", action = "filter", filter = type, value = name, gui_id = gui_id }
    },
  })

end

function util.slot_table_update_train(icon_table, sources, gui_id)
  local new_table = {}
  for k, y in pairs(sources) do

    local type = k == "items" and "item" or "fluid"
    for name, count in pairs(y) do
      local row = {}
      row.type = type
      row.name = name
      row.count = count
      row.color = nil
      table.insert(new_table, row)
    end
  end

  util.slot_table_update(icon_table, new_table, gui_id)

end

function util.signal_for_entity(entity)
  local empty_signal = { type = "virtual", name = "signal-0" }
  if not entity then return empty_signal end
  if not entity.valid then return empty_signal end

  local k, v = next(entity.prototype.items_to_place_this)
  if k then
    return { type = "item", name = v.name }
  end
  return empty_signal
end

function util.matches_filter(result, filters)
  if result.last_change < filters.time_period then
    return false
  end

  local matches_item = filters.item == nil
  local matches_fluid = filters.fluid == nil
  local matches_station = filters.search_field == ""
  if matches_item and matches_fluid and matches_station then
    return true
  end
  for _, event in pairs(result.events) do
    if not matches_item and event.contents then
      matches_item = event.contents[filters.item]
    end
    if not matches_fluid and event.fluids then
      matches_fluid = event.fluids[filters.fluid]
    end
    if not matches_station and event.station then
      local search_field = event.station.valid and event.station.backer_name or ""
      if search_field:lower():find(filters.search_field) then
        matches_station = true
      end
    end
    if matches_item and matches_fluid and matches_station then
      return true
    end
  end
  return false
end

function util.iterate_backwards_iterator(tbl, i)
  i = i - 1
  if i ~= 0 then
    return i, tbl[i]
  end
end

function util.iterate_backwards(tbl)
  return util.iterate_backwards_iterator, tbl, table_size(tbl) + 1
end

--- Open train GUI for one player.
--- @param player_index number
--- @param entity LuaEntity
--- @return boolean gui_opened If the GUI was opened.
function util.open_gui(player_index, entity)
  if entity and entity.valid and game.players[player_index] then
    game.players[player_index].opened = entity
    return true
  end
  return false
end

---Split inputstr by sep and return a table, thanks Internet
---@param inputstr any
---@param sep string
---@return table
function util.split(inputstr, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
    table.insert(t, str)
  end
  return t
end

return util
