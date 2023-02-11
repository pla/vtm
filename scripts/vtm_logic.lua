local on_tick_n = require("__flib__.on-tick-n")
local tables = require("__flib__.table")
local constants = require("__vtm__.scripts.constants")
local gui_util = require("__vtm__.scripts.gui.utils")
local util = require("__core__.lualib.util")
local flib_train = require("__flib__.train")

local MAX_KEEP = 60 * 60 * 60 * 5 -- ticks * seconds * minutes * hours
local last_sweep = 0

local vtm_logic = {}

---@class GuessPatterns
---@field depot table
---@field refuel table
---@field requester table
---@field provider table
function vtm_logic.load_guess_patterns()
  if not global.settings["patterns"] then
    global.settings["patterns"] = {} --[[@as GuessPatterns ]]
  end
  global.settings["patterns"] = {
      depot = util.split(settings.global["vtm-depot-names"].value:lower(), ","),
      refuel = util.split(settings.global["vtm-refuel-names"].value:lower(), ","),
      requester = util.split(settings.global["vtm-requester-names"].value:lower(), ","),
      provider = util.split(settings.global["vtm-provider-names"].value:lower(), ","),
  }
end

---Try to guess the station type: Requester, Provider, Depot or Refuel
---@param station LuaEntity
---@return string
local function guess_station_type(station)
  local station_type = "ND"
  local is_refuel, is_depot, is_provider, is_requester, is_hidden
  local from_start = settings.global["vtm-p-or-r-start"].value
  local patterns = global.settings["patterns"] --[[@as GuessPatterns ]]
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
---@return integer
local function get_TCS_prio(backer_name)
  if game.active_mods["Train_Control_Signals"] then
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
  if surface.valid and not global.surfaces[surface.name] then
    -- excluded sufaces, eg. Editor extensions
    for key, _ in pairs(constants.hidden_surfaces) do
      if surface.name:find(key, 1, true) then
        return
      end
    end
    global.surfaces[surface.name] = surface.name
  end
end
---New Station template and surface registration
---@param station LuaEntity
---@return table
local function new_station(station)
  register_surface(station.surface)
  return {
      force_index = station.force.index,
      station = station,
      created = game.tick,
      last_changed = game.tick,
      opened = "",
      closed = "",
      avg = 0, --TODO : calculate on finish log
      train_front_rail = nil,
      type = guess_station_type(station), -- one of P R D F H or ND
      sort_prio = get_TCS_prio(station.backer_name),
      incoming_trains = {},
      stock = {},
      in_transit = {},
  }
end

function vtm_logic.init_stations()
  if table_size(global.stations) > 0 then
    vtm_logic.update_all_stations("force")
    return
  end
  local train_stops = game.get_train_stops()
  local stations = {}
  for _, station in pairs(train_stops) do
    stations[station.unit_number] = new_station(station)
  end
  global.stations = stations
end

-- unused, for now, needs to be different for P and R
function vtm_logic.update_station_limit(unit_number, station)
  local station_data = global.stations[unit_number]
  if station.station_limit < 1 then
    station_data.closed = game.tick
  elseif station.station_limit > 0 and station.station_limit < constants.MAX_LIMIT then
  end
end

function vtm_logic.update_station(station)
  -- special function for for_n_of
  if not station.valid then
    return 0, true
  end
  if global.stations[station.unit_number] then
    register_surface(station.surface)
    local station_data = global.stations[station.unit_number]
    station_data.force_index = station.force.index
    station_data.station = station
    station_data.last_changed = game.tick
    station_data.type = guess_station_type(station) or "ND" -- one of P R D F or ND
    station_data.sort_prio = get_TCS_prio(station.backer_name)
    if station_data.incoming_trains == nil then
      station_data.incoming_trains = {}
    end
  else
    global.stations[station.unit_number] = new_station(station)
  end
  return station.unit_number, true
end

---@param mode string
function vtm_logic.update_all_stations(mode)
  if mode == "force" then
    local train_stops = game.get_train_stops()
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
  if global.station_k then return end

  global.station_update_table = game.get_train_stops()
  if next(global.station_update_table) then
    game.print({ "vtm.station-refresh-start" })
    global.station_k = 1
  end
end

function vtm_logic.clear_invalid_stations()
  local older_than = game.tick - MAX_KEEP
  local stations = global.stations
  for key, station_data in pairs(stations) do
    if station_data.last_changed < older_than and
        station_data.station.valid == false then
      stations[key] = nil
    end
  end
end

local function trim_old_history(older_than)
  local size = table_size(global.history)
  if size < 10 or game.tick - last_sweep < 720 then return end
  while global.history[size].last_change <= older_than do
    table.remove(global.history, size)
    size = size - 1
  end
  last_sweep = game.tick
end

local function clear_older_force(force, older_than)
  local force_index = force.index
  local size = table_size(global.history)
  while global.history[size].last_change <= older_than and size > 1 do
    if global.history[size].force_index == force_index then
      table.remove(global.history, size)
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
    if game.active_mods["cybersyn"] then
      -- timings will be off because of the depot waiting time
      if schedule.current == 2 then
        index = schedule.current
      end
      -- search with TCS signals in mind
    elseif game.active_mods["Train_Control_Signals"] then
      local pattern = "[virtual-signal=skip-signal]"
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
---@return table
local function new_current_log(train)
  return {
      -- Required because front_stock might not be valid later
      force_index = train.front_stock.force.index,
      train = train,
      started_at = game.tick,
      last_change = game.tick,
      composition = flib_train.get_composition_string(train),
      prototype = train.front_stock.prototype,
      sprite = "item/" .. gui_util.signal_for_entity(train.front_stock).name,
      contents = {},
      events = {}
  }
end

local function diff(old_values, new_values)
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
  if not global.trains[train_id] then
    global.trains[train_id] = new_current_log(train)
  end

  return global.trains[train_id]
end

function vtm_logic.get_logs(force)
  return tables.filter(global.trains, function(train_data)
        return train_data.force_index == force.index
      end)
end

local function add_log(train_data, log_event)
  train_data.last_change = game.tick
  table.insert(train_data.events, log_event)
end

local function finish_current_log(train, train_id, train_data)
  local surface = train.front_stock.surface.name
  train_data.surface = surface
  table.insert(global.history, 1, train_data)
  if train_data.surface2 then
    -- train passed SE elevator
    local data = tables.deep_copy(train_data)
    data.surface = data.surface2
    table.insert(global.history, 1, data)
  end
  local new_data = new_current_log(train)
  global.trains[train_id] = new_data
  trim_old_history(game.tick - MAX_KEEP)
  -- log(serpent.block(train_data)) --FIXME: remove line
end

function vtm_logic.migrate_train_SE(event)
  local old_train_id = event.old_train_id_1
  local train = event.train
  local new_train_id = train.id
  local old_train_data = global.trains[event.old_train_id_1]
  if old_train_data then
    old_train_data.surface2 = game.surfaces[event.old_surface_index].name
    local log = {
        tick = game.tick,
        se_elevator = true,
        position = event.train.front_stock.position,
        old_tick = old_train_data.last_change,
    }
    local new_train_data = old_train_data
    new_train_data.train = train
    new_train_data.surface = train.front_stock.surface.name
    add_log(new_train_data, log)

    -- for train cargo in transit
    if old_train_data.path_end_stop ~= nil then
      global.stations[old_train_data.path_end_stop].incoming_trains[old_train_id] = nil
      global.stations[old_train_data.path_end_stop].incoming_trains[new_train_id] = true
    end
    -- finally save new train and delete old data
    global.trains[new_train_id] = new_train_data
    global.trains[old_train_id] = nil
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
      state = train.state
  }

  if train_data.last_station and event.old_state ~= defines.train_state.wait_station then
    train_data.last_station = nil
  end

  if event.old_state == defines.train_state.wait_station then
    log.position = train.front_stock.position

    local diff_items = diff(train_data.contents.items, train.get_contents())
    local diff_fluids = diff(train_data.contents.fluids, train.get_fluid_contents())
    train_data.contents = read_contents(train)
    log.diff = {
        items = diff_items,
        fluids = diff_fluids
    }
    log.station = train_data.last_station
    train_data.last_station = nil
  end

  if new_state == defines.train_state.wait_station then
    -- always log position
    log.position = train.front_stock.position
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
  if train.path_end_stop and global.stations[train.path_end_stop.unit_number] == nil then
    global.stations[train.path_end_stop.unit_number] = new_station(train.path_end_stop)
  end
  if train.has_path and train.path_end_stop then
    train_data.path_end_stop = train.path_end_stop.unit_number
    global.stations[train.path_end_stop.unit_number].incoming_trains[train_id] = true
  else
    if train_data.path_end_stop ~= nil then
      global.stations[train_data.path_end_stop].incoming_trains[train_id] = nil
      train_data.path_end_stop = nil
    end
  end
  add_log(train_data, log)
end

local function on_trainstop_build(event)
  if event.created_entity.name == "train-stop" then
    -- add_new_station(event.entity)
    -- create ne stop only if it has proper type
    local station_data = new_station(event.created_entity)
    if station_data.type ~= "ND" then
      global.stations[event.created_entity.unit_number] = station_data
    end
  end
end

local function on_trainstop_renamed(event)
  if event.entity.type == "train-stop" then
    local station_data = global.stations[event.entity.unit_number]
    if station_data then
      station_data.sort_prio = get_TCS_prio(event.entity.backer_name)
      station_data.force_index = event.entity.force.index
      station_data.station = event.entity
      station_data.last_changed = game.tick
      station_data.type = guess_station_type(event.entity) or "ND" -- one of P R D F or ND
    else
      global.stations[event.entity.unit_number] = new_station(event.entity)
    end
    if not event.player_index then
      event.player_index = event.entity.last_user.index
    end
    -- LOG(serpent.block(event))
    script.raise_event(constants.refresh_event, {
        event = event,
        player_index = event.player_index
    })
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
  -- TODO trigger station refresh from train path_end_stop :/
  -- worth nothing if there is nothing ready to deliver
  -- better make that available in a different way
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
