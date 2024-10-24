-- gui/util.lua
local gui = require("__flib__.gui")
local flib_box = require("__flib__.bounding-box")

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

function util.default_list_box(name, action, item_data, items_num, refs_table, style)
  if item_data == nil then
    --default list
    item_data = {}
  end
  local content = {
    type = "list-box",
    style = style,
    ref = refs_table,
    name = name,
    style_mods = {
      minimal_height           = items_num * 28,
      maximal_height           = items_num * 28,
      horizontally_stretchable = true
    },
    items = item_data,
    actions = {
      on_selection_state_changed = { type = action.type, action = action.action, gui_id = action.gui_id }
    },
  }
  return content
end

function util.read_inbound_trains(station_data)
  local station = station_data.station
  local contents = {}
  local inv_trains = {}
  if station.valid and station_data.incoming_trains then
    local trains = station_data.incoming_trains
    for train_id, _ in pairs(trains) do
      local train_data = global.trains[train_id]
      if train_data and train_data.train.valid then
        if train_data.path_end_stop == station.unit_number then
          for type, item_data in pairs(train_data.contents) do
            local row = {}
            row.type = type == "items" and "item" or "fluid"
            for name, count in pairs(item_data) do --FIXME
              row.name = name
              row.count = count
              row.color = "blue"
              table.insert(contents, row)
            end
          end
        end
      else
        table.insert(inv_trains, train_id)
      end
    end
    -- delete invalid traindata
    for _, train_id in pairs(inv_trains) do
      global.trains[train_id] = nil
      station_data.incoming_trains[train_id] = nil
    end
  end
  return contents
end

---Slave table will be added to master table
---@param master SlotTableDef[]
---@param slave SlotTableDef[]
function util.merge_slot_tables(master, slave)
  if table_size(slave) == 0 then return end
  for _, add in pairs(slave) do
    local found = false
    for _, row in pairs(master) do
      if row.type == add.type and row.name == add.name then
        row.count = row.count + add.count
        found = true
      end
    end
    if not found then
      table.insert(master, add)
    end
  end
end

--- Creates a non-scrollable slot table.
--- @param widths table
--- @param style? string
--- @param name string
function util.slot_table(widths, style, name)
  return {
    type = "table",
    name = name .. "_table",
    style = style and game.styles[style] or "slot_table",
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

--- Updates a slot table based on the passed criteria.
--- @param icon_table LuaGuiElement
--- @param sources SlotTableDef[]
--- @param gui_id uint
--- @param max_lines uint?
function util.slot_table_update(icon_table, sources, gui_id, max_lines)
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
    if max_lines and i == (icon_table.column_count * max_lines) then break end
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
  if prototype and game.is_valid_sprite_path(type .. "/" .. name) then
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

---Return Zoom level for minimap
---@param area BoundingBox
---@return double
function util.get_zoom_from_area(area)
  local zoom = 1.0
  if area then
    local width = flib_box.width(area)
    local height = flib_box.height(area)
    local max = math.max(width, height)
    --[[
      zoom=1 - 130 *2 = 260
      zoom1.5 - 86 *2 = 172
      zoom=2 - 65 *2 = 130
      zoom=3 - 44 *2 = 88
      ]]
    if max > 260 then
      zoom = 0.5
    elseif max > 172 then
      zoom = 1
    elseif max > 130 then
      zoom = 1.5
    elseif max > 88 then
      zoom = 2
    elseif max <= 88 then
      zoom = 3
    end
  end

  return zoom
end

function util.signal_for_entity(entity)
  local empty_signal = { type = "virtual", name = "signal-0" }
  if not entity then return empty_signal end
  if not entity.valid then return empty_signal end
  if game.is_valid_sprite_path("item/" .. entity.prototype.name) then
    return { type = "item", name = entity.prototype.name }
  end
  return empty_signal
end

function util.signal_to_sprite(signal)
  if not signal then return nil end
  if game.is_valid_sprite_path(signal.type .. "/" .. signal.name) then
    return signal.type .. "/" .. signal.name
  end

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

--- Open entity GUI for one player. eg LuaTrain
--- @param player_index number
--- @param entity LuaEntity
--- @return boolean --gui_opened If the GUI was opened.
function util.open_entity_gui(player_index, entity)
  if entity and entity.valid and game.players[player_index] then
    game.players[player_index].opened = entity
    return true
  end
  return false
end

---view station with Navsat on SE
---@param player LuaPlayer
---@param surface_name string LuaSurface.name
---@param position MapPosition
function util.show_remote_position(player, surface_name, position)
  if not player or not surface or not position then return end
  if global.SE_active and remote.interfaces["space-exploration"]["remote_view_start"]
  then
    remote.call("space-exploration", "remote_view_start", {
      player = player,
      zone_name = global.surfaces[surface_name],
      position = position,
      -- location_name="Point of Interest",
      -- freeze_history=true
    })
  end
end

--- show train with Navsat on SE
---@param player LuaPlayer
---@param loco LuaEntity
function util.follow_remote_train(player, loco)
  if not player or not loco or not loco.valid then return end
  if global.SE_active and remote.interfaces["space-exploration"]["remote_view_start"]
  then
    remote.call("space-exploration", "remote_view_start", {
      player = player,
      zone_name = global.surfaces[loco.surface.name],
      position = loco.position,
      -- location_name="Point of Interest",
      -- freeze_history=true
    })
  end
end

--- set a style for the given LuaGuiElement
---@param element LuaGuiElement
---@param style string must be a gui-style name
function util.set_style(element, style)
  gui.update(element, {
    style = style
  })
end

---Check if string ends with given string
---@param str string
---@param search string
---@return boolean
function util.string_ends_with(str, search)
  return string.sub(str, (string.len(search) * -1)) == search
end

return util
