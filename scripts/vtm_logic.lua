local on_tick_n = require("__flib__.on-tick-n")
local tables = require("__flib__.table")
local constants = require("__virtm__.scripts.constants")
local gui_util = require("__virtm__.scripts.gui.utils")
local util = require("__core__.lualib.util")
local flib_train = require("__flib__.train")

local MAX_KEEP = 60 * 60 * 60 * 5 -- ticks * seconds * minutes * hours
local last_sweep = 0

local vtm_logic = {}

function vtm_logic.load_guess_patterns()
  storage.settings["patterns"] = {
    depot = util.split(tostring(settings.global["vtm-depot-names"].value):lower(), ","),
    refuel = util.split(tostring(settings.global["vtm-refuel-names"].value):lower(), ","),
    requester = util.split(tostring(settings.global["vtm-requester-names"].value):lower(), ","),
    provider = util.split(tostring(settings.global["vtm-provider-names"].value):lower(), ","),
  }
end

function vtm_logic.cache_generic_settings()
  storage.surface_selector_visible = settings.global["vtm-force-surface-visible"].value
  storage.max_hist                 = settings.global["vtm-history-length"].value
  storage.max_lines                = settings.global["vtm-limit-auto-refresh"].value
  storage.show_undef_warn          = settings.global["vtm-show-undef-warning"].value
  storage.dont_read_depot_stock    = settings.global["vtm-dont-read-depot-stock"].value
  storage.pr_from_start            = settings.global["vtm-p-or-r-start"].value
  storage.showSpaceTab             = settings.global["vtm-showSpaceTab"].value and storage.SA_active or false
  storage.name_new_station         = settings.global["vtm-name-new-station"].value
  storage.new_station_name         = settings.global["vtm-new-station-name"].value

  storage.backer_names             = {}
  for _, name in pairs(game.backer_names) do
    storage.backer_names[name] = true
  end
end

---Try to guess the station type: Requester, Provider, Depot or Refuel
---@param station LuaEntity
---@return string
local function guess_station_type(station)
  local station_type = "ND"
  local is_refuel, is_depot, is_provider, is_requester, is_hidden
  local from_start = settings.global["vtm-p-or-r-start"].value
  local patterns = storage.settings["patterns"] --[[@as GuessPatterns ]]
  -- depot
  for _, pattern in pairs(patterns.depot) do
    if pattern:sub(1, 1) == "-" then
      is_hidden = true
      is_depot = string.find(string.lower(station.backer_name), pattern:sub(2), 1, true) or false
    else
      is_hidden = false
      is_depot = string.find(string.lower(station.backer_name), pattern, 1, true) or false
    end
    if is_hidden and is_depot then
      return "H"
    end
    if is_depot then
      return "D"
    end
  end
  -- refuel
  for _, pattern in pairs(patterns.refuel) do
    is_refuel = string.find(string.lower(station.backer_name), pattern, 1, true) or false
    if is_refuel then
      return "F"
    end
  end
  -- requester
  for _, pattern in pairs(patterns.requester) do
    local start = pattern:len() * -1
    if from_start then
      start = 1
    end
    is_requester = string.find(string.lower(station.backer_name), pattern, start, true) or false
    if is_requester then
      return "R"
    end
  end

  -- provider
  for _, pattern in pairs(patterns.provider) do
    local start = pattern:len() * -1
    if from_start then
      start = 1
    end
    is_provider = string.find(string.lower(station.backer_name), pattern, start, true) or false
    if is_provider then
      return "P"
    end
  end
  return station_type
end

---extra sort criteria to sort depots tab, TCS Depot always first
---@param backer_name string
---@return uint
local function get_TCS_prio(backer_name)
  if storage.TCS_active then
    local tcs_refuel = "[virtual-signal=refuel-signal]"
    local tcs_depot = "[virtual-signal=depot-signal]"
    -- local tcs_skip = "[virtual-signal=skip-signal]"
    local is_depot = string.find(string.lower(backer_name), tcs_depot, 1, true) or false
    if is_depot then
      return 1
    end
    local is_refuel = string.find(string.lower(backer_name), tcs_refuel, 1, true) or false
    if is_refuel then
      return 2
    end
  end
  return 9
end

local function register_surface(surface)
  if surface.valid and not storage.surfaces[surface.name] then
    -- excluded sufaces, eg. Editor extensions
    for key, _ in pairs(constants.hidden_surfaces) do
      if surface.name:find(key, 1, true) then
        return
      end
    end
    if surface.planet and surface.planet.prototype.localised_name then
      storage.surfaces[surface.name] = { "", "[planet=", surface.name, "] ", surface.planet.prototype.localised_name }
    else
      storage.surfaces[surface.name] = surface.name
    end
  end
end

---New Station template and surface registration
---@param station LuaEntity
---@return table StationData
local function new_station(station)
  register_surface(station.surface)
  return {
    force_index = station.force_index,
    station = station,
    created = game.tick,
    last_changed = game.tick,
    opened = 0,
    closed = 0,
    sprite = gui_util.signal_to_sprite(gui_util.signal_for_entity(station)),
    train_front_rail = nil,
    type = guess_station_type(station), -- one of P R D F H or ND
    sort_prio = get_TCS_prio(station.backer_name),
    stock = {},
    in_transit = {},
    registered_stock = {},
  }
end

function vtm_logic.init_stations()
  if table_size(storage.stations) > 0 then
    vtm_logic.update_all_stations("force")
    return
  end
  local train_stops = game.train_manager.get_train_stops({})
  local stations = {}
  for _, station in pairs(train_stops) do
    stations[station.unit_number] = new_station(station)
  end
  storage.stations = stations
end

-- unused, for now, needs to be different for P and R
function vtm_logic.update_station_limit(unit_number, station)
  local station_data = storage.stations[unit_number]
  if station.station_limit < 1 then
    station_data.closed = game.tick
  elseif station.station_limit > 0 and station.station_limit < constants.MAX_LIMIT then
  end
end

---comment
---@param station_data StationData
---@param type "item"|"fluid"|"virtual" signalID type
---@param name string signalID name
---@param quality string
local function register_item(station_data, type, name, quality)
  local found = false
  -- register item
  for _, row in pairs(station_data.registered_stock) do
    if row.type == type and row.name == name and row.quality == quality then
      found = true
      break
    end
  end
  if not found then
    table.insert(station_data.registered_stock, { type = type, name = name, quality = quality, count = 0 })
  end
end

---Read items from Station circuit network
---@param station_data StationData
---@param return_virtual boolean?
---@return SlotTableDef
---@return boolean --Is the limit set by circuit (true)or manual(false)
function vtm_logic.read_station_network(station_data, return_virtual)
  local station = station_data.station
  local contents = {} --[[@type SlotTableDef[] ]]
  local set_trains_limit = false
  local cb = station.get_or_create_control_behavior() --[[@as LuaTrainStopControlBehavior]]
  set_trains_limit = cb.set_trains_limit
  -- argue against get_merged_signals- loose wire color info
  for _, wire in pairs({ defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green }) do
    local cn = station.get_circuit_network(wire)
    -- cn - signals (type,name),wire_type
    if cn ~= nil and cn.signals ~= nil then
      for _, signal_data in pairs(cn.signals) do
        if signal_data.signal.type ~= "virtual" or return_virtual == true then
          local signal_type = signal_data.signal.type
          if signal_type == nil then
            signal_type = "item"
          end
          local quality = signal_data.signal.quality or "normal"
          register_item(station_data, signal_type, signal_data.signal.name, quality)
          table.insert(contents, {
            type = signal_type,
            name = signal_data.signal.name,
            quality = quality,
            count = signal_data.count,
            color = constants.wire_colors[wire]
          })
        end
      end
    end
  end

  return contents, set_trains_limit
end

---@param group_id uint
---@param read_stock boolean?
---@return GroupData|nil
function vtm_logic.read_group(group_id, read_stock)
  local p_station = storage.stations[group_id].station
  local group_data = storage.groups[p_station.force_index][p_station.unit_number] --[[@as GroupData]]
  if not group_data then return end

  if group_data then
    for _, station_data in pairs(group_data.members) do
      if station_data and station_data.station and station_data.station.valid then
        if station_data.stock_tick <= game.tick - 60 and read_stock then
          ---@type SlotTableDef
          local items = vtm_logic.read_station_network(station_data)
          station_data.stock_tick = game.tick
          station_data.stock = items
        end
      end
    end
  end
  return group_data
end

function vtm_logic.read_group_id(station)
  if station.valid then
    local group_data = storage.groups[station.force_index][station.unit_number]
    if group_data then
      return group_data.group_id
    end
  end
end

function vtm_logic.get_or_create_station_data(station)
  ---@type StationData
  local station_data = storage.stations[station.unit_number]
  if not station_data then
    station_data = new_station(station)
    storage.stations[station.unit_number] = station_data
  end
  return station_data
end

function vtm_logic.update_station(station)
  -- special function for for_n_of
  if not station.valid then
    return 0, true
  end
  if storage.stations[station.unit_number] then
    register_surface(station.surface)
    local station_data = storage.stations[station.unit_number]
    station_data.force_index = station.force.index
    station_data.station = station
    station_data.last_changed = game.tick
    station_data.type = guess_station_type(station) or "ND" -- one of P R D F or ND
    station_data.sort_prio = get_TCS_prio(station.backer_name)
    station_data.stock = {}
    station_data.in_transit = {}
    if station_data.registered_stock == nil then
      station_data.registered_stock = {}
    end
    if station_data.sprite == nil then
      station_data.sprite = gui_util.signal_to_sprite(gui_util.signal_for_entity(station_data.station)) or
          "item/train-stop"
    end
  else
    storage.stations[station.unit_number] = new_station(station)
  end
  return station.unit_number, true
end

---@param mode string
function vtm_logic.update_all_stations(mode)
  if mode == "force" then
    local train_stops = game.train_manager.get_train_stops({})
    for _, station in pairs(train_stops) do
      vtm_logic.update_station(station)
    end
  elseif mode == "split" then
    -- on_tick_n for_n_of
    vtm_logic.schedule_station_refresh()
  end
  vtm_logic.clear_invalid_stations()
end

function vtm_logic.schedule_station_refresh()
  if storage.station_k then return end

  storage.station_update_table = game.train_manager.get_train_stops({})
  if next(storage.station_update_table) then
    game.print({ "vtm.station-refresh-start" })
    storage.station_k = 1
  end
end

function vtm_logic.clear_invalid_stations()
  local older_than = game.tick - MAX_KEEP
  local stations = storage.stations
  for key, station_data in pairs(stations) do
    if station_data.last_changed < older_than and
        station_data.station.valid == false then
      stations[key] = nil
    end
  end
end

local function trim_old_history(older_than)
  local size = table_size(storage.history)
  if size < 10 or game.tick - last_sweep < 720 then return end
  while storage.history[size].last_change <= older_than do
    table.remove(storage.history, size)
    size = size - 1
  end
  last_sweep = game.tick
end

local function clear_older_force(force, older_than)
  local force_index = force.index
  local size = table_size(storage.history)
  while size > 1 and storage.history[size].last_change <= older_than do
    if storage.history[size].force_index == force_index then
      table.remove(storage.history, size)
      size = size - 1
    end
  end
  last_sweep = game.tick
end

function vtm_logic.clear_older(player_index, older_than)
  local force = game.players[player_index].force
  clear_older_force(force, older_than)
  force.print { "vtm.player-cleared-history", game.players[player_index].name }
end

---Find start of schedule, to finish the current log and start a new one
---@param schedule TrainSchedule
---@return integer
local function find_first_stop(schedule)
  local index = 1
  if schedule ~= nil and schedule.records then
    if storage.cybersyn_active then
      -- timings will be off because of the depot waiting time
      if schedule.current == 2 then
        index = schedule.current
      end
      -- search with TCS signals in mind
    elseif storage.TCS_active then
      local pattern = "[virtual-signal=skip-signal]" -- TODO: this can go away
      for key, record in pairs(schedule.records) do
        if record.station ~= nil then
          local start = string.sub(record.station, 1, string.len(pattern))
          if start ~= pattern then
            return key
          end
        end
      end
    end
  end
  return index
end

---comment
---@param train LuaTrain
---@return table|nil
local function new_current_log(train)
  local loco = flib_train.get_main_locomotive(train)
  if not loco then return end
  return {
    force_index = loco.force_index,
    train = train,
    started_at = game.tick,
    last_change = game.tick,
    composition = flib_train.get_composition_string(train),
    prototype = loco.prototype,
    sprite = "item/" .. gui_util.signal_for_entity(loco).name,
    contents = {},
    events = {}
  }
end

---comment
---@param old_values ItemWithQualityCounts[]
---@param new_values ItemWithQualityCounts[]
---@return table
local function diff_items(old_values, new_values)
  local result = {}
  if old_values then
    for k, v in pairs(old_values) do
      local key = v.name .. v.quality
      -- result[k] = -v
      result[k] = v
      result[k].count = -v.count
    end
  end
  if new_values then
    for _, v in pairs(new_values) do
      local key = v.name .. v.quality
      local old_count = 0
      if result[key] then
        old_count = result[key].count
      else
        result[key] = v
      end
      result[key].count = old_count + v.count
    end
  end
  return result
end

local function diff_fluids(old_values, new_values)
  local result = {}
  if old_values then
    for k, v in pairs(old_values) do
      result[k] = -v
    end
  end
  if new_values then
    for k, v in pairs(new_values) do
      local old_value = result[k] or 0
      result[k] = old_value + v
    end
  end
  return result
end


local function get_train_data(train, train_id)
  if not storage.trains[train_id] then
    storage.trains[train_id] = new_current_log(train)
  end

  return storage.trains[train_id]
end

function vtm_logic.get_logs(force)
  return tables.filter(storage.trains, function(train_data)
    return train_data.force_index == force.index
  end)
end

local function add_log(train_data, log_event)
  train_data.last_change = game.tick
  table.insert(train_data.events, log_event)
end

---Finish the current log for the train, put it in history and create a new log
---@param train LuaTrain
---@param train_id uint
---@param train_data TrainData
local function finish_current_log(train, train_id, train_data)
  local surface = train.carriages[1].surface.name
  train_data.surface = surface
  table.insert(storage.history, 1, train_data)
  if train_data.surface2 then
    -- train passed SE elevator
    local data = tables.deep_copy(train_data)
    data.surface = data.surface2
    table.insert(storage.history, 1, data)
  end
  local new_data = new_current_log(train)
  storage.trains[train_id] = new_data
  trim_old_history(game.tick - MAX_KEEP)
  -- log(serpent.block(train_data)) --FIXME: remove line
end

function vtm_logic.migrate_train_SE(event)
  local old_train_id = event.old_train_id_1
  local train = event.train
  local new_train_id = train.id
  local old_train_data = storage.trains[event.old_train_id_1]
  if old_train_data then
    old_train_data.surface2 = game.surfaces[event.old_surface_index].name
    local log = {
      tick = game.tick,
      se_elevator = true,
      position = event.train.carriages[1].position,
      old_tick = old_train_data.last_change,
    }
    local new_train_data = old_train_data
    new_train_data.train = train
    new_train_data.surface = train.carriages[1].surface.name
    add_log(new_train_data, log)

    -- finally save new train and delete old data
    storage.trains[new_train_id] = new_train_data
    storage.trains[old_train_id] = nil
  end
end

local function read_contents(train)
  return {
    items = train.get_contents(),
    fluids = train.get_fluid_contents()
  }
end
local function on_train_changed_state(event)
  local train = event.train
  local train_id = train.id
  local train_data = get_train_data(train, train_id)
  if not train_data then return end -- some SE things, just ignore it
  local new_state = train.state
  local interesting_event = constants.interesting_states[event.old_state] or constants.interesting_states[new_state]
  if not interesting_event then
    return
  end
  -- can we finish
  if train.state == defines.train_state.arrive_station and train.schedule.current == find_first_stop(train.schedule) then
    finish_current_log(train, train_id, train_data)
    return
  elseif train.state == defines.train_state.arrive_station then
    return
  end

  local log = {
    tick = game.tick,
    old_state = event.old_state,
    state = train.state,
    position = train.carriages[1].position
  }

  if train_data.last_station and event.old_state ~= defines.train_state.wait_station then
    train_data.last_station = nil
  end

  if event.old_state == defines.train_state.wait_station then
    local item_diff = diff_items(train_data.contents.items, train.get_contents())
    local fluid_diff = diff_fluids(train_data.contents.fluids, train.get_fluid_contents())
    train_data.contents = read_contents(train)
    log.diff = {
      items = item_diff,
      fluids = fluid_diff
    }
    log.station = train_data.last_station
    train_data.last_station = nil
  end

  if new_state == defines.train_state.wait_station then
    if train.station then
      train_data.contents = read_contents(train)
      train_data.last_station = train.station
      log.contents = train_data.contents.items
      log.fluids = train_data.contents.fluids
      log.station = train.station
    end
  end

  if event.old_state == defines.train_state.destination_full and
      train.state == defines.train_state.on_the_path
  then
    log.old_tick = train_data.last_change
  end

  -- for train cargo in transit
  if train.path_end_stop and storage.stations[train.path_end_stop.unit_number] == nil then
    storage.stations[train.path_end_stop.unit_number] = new_station(train.path_end_stop)
  end
  if train.has_path and train.path_end_stop then
    train_data.path_end_stop = train.path_end_stop.unit_number
  else
    if train_data.path_end_stop ~= nil then
      train_data.path_end_stop = nil
    end
  end
  add_log(train_data, log)
end

--TODO create Combinator with all signals from Station items for paired crafter
local function on_trainstop_build(event)
  if event.entity.name == "train-stop" then
    if settings.global["vtm-name-new-station"].value and storage.backer_names[event.entity.backer_name] then
      event.entity.backer_name = settings.global["vtm-new-station-name"].value
    end
    local station_data = new_station(event.entity)
    storage.stations[event.entity.unit_number] = station_data
  end
end

local function on_trainstop_renamed(event)
  if event.entity.type == "train-stop" then
    local station_data = storage.stations[event.entity.unit_number]
    if station_data then
      station_data.sort_prio = get_TCS_prio(event.entity.backer_name)
      station_data.force_index = event.entity.force.index
      station_data.station = event.entity
      station_data.last_changed = game.tick
      station_data.type = guess_station_type(event.entity) or "ND" -- one of P R D F or ND
    else
      storage.stations[event.entity.unit_number] = new_station(event.entity)
    end
    if not event.player_index then
      event.player_index = event.entity.last_user.index
    end
    -- log(serpent.block(event))
    -- script.raise_event(constants.refresh_event, {
    --   event = event,
    --   player_index = event.player_index
    -- })
  end
end

local function on_train_schedule_changed(event)
  local train = event.train
  local train_id = train.id
  if not event.player_index then
    return
  end
  local train_data = get_train_data(train, train_id)
  add_log(train_data, {
    tick = game.tick,
    schedule = train.schedule,
    changed_by = event.player_index
  })
end

-- EVENTS

script.on_event(defines.events.on_train_changed_state, function(event)
  on_train_changed_state(event)
end)

-- script.on_event(defines.events.on_train_schedule_changed, function(event)
--   on_train_schedule_changed(event)
-- end)

script.on_event(defines.events.on_built_entity, function(event)
    on_trainstop_build(event)
  end,
  { { filter = "type", type = "train-stop" } })

script.on_event(defines.events.on_robot_built_entity, function(event)
    on_trainstop_build(event)
  end,
  { { filter = "type", type = "train-stop" } })

script.on_event(defines.events.on_entity_renamed, function(event)
  if event.entity.type == "train-stop" then
    on_trainstop_renamed(event)
  end
end)

return vtm_logic
