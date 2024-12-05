-- gui/util.lua
local flib_gui   = require("__flib__.gui")
local flib_box   = require("__flib__.bounding-box")
local constants  = require("__virtm__.scripts.constants")
local flib_table = require("__flib__.table")

local utils      = {}
utils.handler = nil

function utils.mouse_button_filter(button_pressed, button_wanted)
  local result = false
  if button_pressed ~= nil
      and defines.mouse_button_type[button_wanted]
      and button_pressed == defines.mouse_button_type[button_wanted] then
    result = true
  end

  return result
end

function utils.get_gui_id(player_index)
  local player = game.get_player(player_index)
  for gui_id, vtm_gui in pairs(storage.guis) do
    if vtm_gui.player == player then
      return gui_id
    end
  end
  return nil
end

function utils.default_list_box(name, action, item_data, items_num, refs_table, style)
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

function utils.contents_to_slot_table(contents, slot_table)
  for type, item_data in pairs(contents) do
    if type == "items" then
      for _, v in pairs(item_data) do
        local row = {}
        row.type = "item"
        row.name = v.name
        row.count = v.count
        row.quality = v.quality
        row.color = "blue"
        table.insert(slot_table, row)
      end
    elseif type == "fluids" then
      --fluids, have no quality
      for name, count in pairs(item_data) do
        local row = {}
        row.type = "fluid"
        row.name = name
        row.count = count
        row.color = nil
        table.insert(slot_table, row)
      end
    end
  end
end

function utils.read_inbound_trains(station_data)
  local station = station_data.station
  local slot_table = {}
  local invalid_trains = {}
  if station.valid and station.trains_count then
    local trains = station.get_train_stop_trains()
    for _, train in pairs(trains) do
      local train_data = storage.trains[train.id]
      if train_data and train_data.train.valid then
        if train_data.path_end_stop == station.unit_number then
          utils.contents_to_slot_table(train_data.contents, slot_table)
        end
      else
        table.insert(invalid_trains, train.id)
      end
    end
    -- delete invalid traindata
    for _, train_id in pairs(invalid_trains) do
      storage.trains[train_id] = nil
    end
  end
  return slot_table
end

---Slave table will be added to master table
---@param master SlotTableDef[]
---@param slave SlotTableDef[]
function utils.merge_slot_tables(master, slave)
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
function utils.slot_table(widths, style, name)
  return {
    type = "table",
    name = name .. "_table",
    style = style and prototypes.style[style] or "slot_table",
    style_mods = {
      width = widths[name],
      minimal_height = 36,
      -- horizontal_spacing = 4,
      -- vertical_spacing = 4,
      cell_padding = 2,
      left_padding = 8,
    },
    column_count = widths[name .. "_columns"],
    -- handler = { [defines.events.on_gui_click] = utils.handler }

  }
end

--- Updates a slot table based on the passed criteria.
--- @param icon_table LuaGuiElement
--- @param sources SlotTableDef[]
--- @param max_lines uint?
function utils.slot_table_update(icon_table, sources, max_lines)
  local children = icon_table.children
  local i = 0
  for _, source_data in pairs(sources) do
    i = i + 1
    local button = children[i]
    if not button then
      _, button = flib_gui.add(icon_table, {
        type = "sprite-button",
        handler = { [defines.events.on_gui_click] = utils.handler }
      })
    end
    utils.update_sprite_button(
      button,
      source_data.type,
      source_data.name,
      source_data.count,
      source_data.quality,
      source_data.color
    )
    -- button.enabled = false
    if max_lines and i == (icon_table.column_count * max_lines) then break end
  end

  for i = i + 1, #children do
    children[i].destroy()
  end
end

-- delete later, seems to be unused
-- function utils.sprite_button_type_name_amount(type, name, amount, color, gui_id) -- todo add quality
--   local prototype = nil
--   if type == "item" then
--     prototype = prototypes.item[name]
--   elseif type == "fluid" then
--     prototype = prototypes.fluid[name]
--   elseif type == "virtual-signal" then
--     prototype = prototypes.virtual_signal[name]
--   end
--   local sprite, tooltip, style
--   if prototype then
--     sprite = type .. "/" .. name
--     if color ~= nil and (color == "red" or color == "green") then
--       local color_item = prototypes.item[color .. "-wire"]
--       tooltip = { "", prototype.localised_name, ", ", color_item.localised_name }
--     else
--       tooltip = prototype.localised_name
--     end
--     style = "transparent_slot"
--   else
--     tooltip = "Error"
--     sprite = "warning-white"
--     style = "flib_tool_button_dark_red"
--   end
--   return {
--     type = "sprite-button",
--     style = style,
--     sprite = sprite,
--     number = amount,
--     actions = {
--       on_click = { type = "searchbar", action = "filter", filter = type, value = name, gui_id = gui_id }
--     },
--     tags = { filter = "filter", type = type, name = name }, --TODO ,quality = quality},
--     tooltip = tooltip
--   }
-- end

function utils.update_sprite_button(button, type, name, amount, quality, color)
  local prototype = nil
  if type == "item" then
    prototype = prototypes.item[name]
  elseif type == "fluid" then
    prototype = prototypes.fluid[name]
  elseif type == "virtual-signal" then
    prototype = prototypes.virtual_signal[name]
  end
  local sprite, tooltip, style
  if prototype and helpers.is_valid_sprite_path(type .. "/" .. name) then
    sprite = type .. "/" .. name
    -- TODO figure out how to display quality sprites
    local item_sprite = nil
    local quali_sprite = nil

    if color ~= nil and (color == "red" or color == "green") then
      local color_item = prototypes.item[color .. "-wire"]
      tooltip = { "", prototype.localised_name, ", ", color_item.localised_name }
    else
      tooltip = prototype.localised_name
    end
    if script.active_mods["quality"] and type == "item" then
      local item_quality = prototypes.quality[quality]
      if helpers.is_valid_sprite_path(item_quality.type .. "/" .. item_quality.name) then
        quali_sprite = item_quality.type .. "/" .. item_quality.name
      end
      tooltip = { "", tooltip, ", [", item_quality.type, "=", item_quality.name, "] ", item_quality.localised_name }
    end
    style = "transparent_slot"
  else
    tooltip = "Error"
    sprite = "warning-white"
    style = "flib_tool_button_dark_red"
  end
  button.sprite = sprite
  button.number = amount
  button.tooltip = tooltip
  button.style = style
  button.tags =flib_table.shallow_merge({ button.tags, { filter = "filter", type = type, name = name } })
  -- button.tags = { filter = "filter", type = type, name = name } --TODO ,quality = quality},
end

function utils.slot_table_update_train(icon_table, sources)
  local slot_table = {}
  utils.contents_to_slot_table(sources, slot_table)
  -- for k, y in pairs(sources) do
  --   -- items
  --   if k == "items" then
  --     for _, v in pairs(y) do
  --       local row = {}
  --       row.type = "item"
  --       row.name = v.name
  --       row.count = v.count
  --       row.quality = v.quality
  --       row.color = nil
  --       table.insert(slot_table, row)
  --     end
  --     --fluids, have no quality
  --   elseif k == "fluids" then
  --     for name, count in pairs(y) do
  --       local row = {}
  --       row.type = "fluid"
  --       row.name = name
  --       row.count = count
  --       row.color = nil
  --       table.insert(slot_table, row)
  --     end
  --   end
  -- end

  utils.slot_table_update(icon_table, slot_table)
end

---Return Zoom level for minimap
---@param area BoundingBox
---@return double, double
function utils.get_zoom_from_area(area)
  local max  = 0
  local zoom = 1.0
  if area then
    local width = flib_box.width(area)
    local height = flib_box.height(area)
    max = math.max(width, height)
    zoom = (1442 * max ^ -0.7) -- + (storage.zoom or 0)

    --[[ zoom Factorio 1.1
      zoom=1 - 130 *2 = 260
      zoom1.5 - 86 *2 = 172
      zoom=2 - 65 *2 = 130
      zoom=3 - 44 *2 = 88
      ]]
    --[[ zoom Factorio 2.0
      zoom=1442*max^-0.7
      ]]
    -- leave that here in case something chengs again
    -- if max > 260 then
    --   -- zoom = 0.5
    --   zoom = zoom
    -- elseif max > 172 then
    --   -- zoom = 1
    --   zoom = zoom
    -- elseif max > 130 then
    --   -- zoom = 1.5
    --   zoom = zoom
    -- elseif max > 88 then
    --   -- zoom = 2
    --   zoom = zoom
    -- elseif max <= 88 then
    --   -- zoom = 3
    --   zoom = zoom
    -- end
  end

  return zoom, max
end

function utils.signal_for_entity(entity)
  local empty_signal = { type = "virtual", name = "signal-0" }
  if not entity then return empty_signal end
  if not entity.valid then return empty_signal end
  if helpers.is_valid_sprite_path("item/" .. entity.prototype.name) then
    return { type = "item", name = entity.prototype.name }
  end
  return empty_signal
end

function utils.signal_to_sprite(signal)
  if not signal then return nil end
  if helpers.is_valid_sprite_path(signal.type .. "/" .. signal.name) then
    return signal.type .. "/" .. signal.name
  end
end

function utils.matches_filter(result, filters)
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

function utils.iterate_backwards_iterator(tbl, i)
  i = i - 1
  if i ~= 0 then
    return i, tbl[i]
  end
end

function utils.iterate_backwards(tbl)
  return utils.iterate_backwards_iterator, tbl, table_size(tbl) + 1
end

--- Open entity GUI for one player. eg LuaTrain
--- @param player_index number
--- @param entity LuaEntity
--- @return boolean --gui_opened If the GUI was opened.
function utils.open_entity_gui(player_index, entity)
  if entity and entity.valid and game.players[player_index] then
    game.players[player_index].opened = entity
    game.players[player_index].zoom = 0.2
    return true
  end
  return false
end

--[[ ---view station with Navsat on SE
---@param player LuaPlayer
---@param surface_name string LuaSurface.name
---@param position MapPosition
function utils.show_remote_position(player, surface_name, position)
  if not player or not surface_name or not position then return end
  if storage.SE_active and remote.interfaces["space-exploration"]["remote_view_start"]
  then
    ---@diagnostic disable-next-line: missing-fields
    remote.call("space-exploration", "remote_view_start", {
      player = player,
      zone_name = storage.surfaces[surface_name],
      position = position,
      -- location_name="Point of Interest",
      -- freeze_history=true
    })
  end
end

--- show train with Navsat on SE
---@param player LuaPlayer
---@param loco LuaEntity
function utils.follow_remote_train(player, loco)
  if not player or not loco or not loco.valid then return end
  if storage.SE_active and remote.interfaces["space-exploration"]["remote_view_start"]
  then
    ---@diagnostic disable-next-line: missing-fields
    remote.call("space-exploration", "remote_view_start", {
      player = player,
      zone_name = storage.surfaces[loco.surface.name],
      position = loco.position,
      -- location_name="Point of Interest",
      -- freeze_history=true
    })
  end
end
]] --- set a style for the given LuaGuiElement
---
---@param element LuaGuiElement
---@param style string must be a gui-style name
function utils.set_style(element, style)
  element.style = style
end

---Check if string ends with given string
---@param str string
---@param search string
---@return boolean
function utils.string_ends_with(str, search)
  return string.sub(str, (string.len(search) * -1)) == search
end

function utils.cache_generic_settings()
  -- cache relevant mods
  storage.TCS_active               = script.active_mods["TCS_Icons"] and true or false
  storage.cybersyn_active          = script.active_mods["cybersyn"] and true or false
  storage.SE_active                = script.active_mods["space-exploration"] and true or false
  storage.SA_active                = script.active_mods["space-age"] and true or false

  storage.surface_selector_visible = settings.global["vtm-force-surface-visible"].value
  storage.max_hist                 = settings.global["vtm-history-length"].value
  storage.max_lines                = settings.global["vtm-limit-auto-refresh"].value
  storage.show_undef_warn          = settings.global["vtm-show-undef-warning"].value
  storage.dont_read_depot_stock    = settings.global["vtm-dont-read-depot-stock"].value
  storage.pr_from_start            = settings.global["vtm-p-or-r-start"].value
  storage.showSpaceTab             = settings.global["vtm-showSpaceTab"].value and storage.SA_active
  storage.name_new_station         = settings.global["vtm-name-new-station"].value
  storage.new_station_name         = settings.global["vtm-new-station-name"].value

  storage.backer_names             = {}
  for _, name in pairs(game.backer_names) do
    storage.backer_names[name] = true
  end
end

function utils.ticks(time_period_index)
  return constants.time_period_items[time_period_index].time * 60
end

---comment
---@param row LuaGuiElement
---@return table
function utils.recreate_gui_refs(row)
  local refs = {}
  if row then
    for key, value in pairs(row.children_names) do
      if value ~= "" then
        refs[value] = row.children[key]
      end
      if row.children[key].children then
        local temp = utils.recreate_gui_refs(row.children[key])
        refs = flib_table.shallow_merge({ refs, temp })
      end
    end
  end
  return refs
end

return utils
