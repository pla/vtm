local on_tick_n = require("__flib__.on-tick-n")
local tables = require("__flib__.table")
local constants = require("scripts.constants")

local MAX_KEEP = 60 * 60 * 60 * 12 -- ticks * seconds * minutes * hours

local vtm_logic = {}

local refuel_pattern = {}
local depot_pattern = {}
local requester_pattern = {}
local provider_pattern = {}

local function split(inputstr, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
    table.insert(t, str)
  end
  return t
end

local function read_station_network(station, return_virtual)
  local contents = {}
  local colors = tables.invert(defines.wire_type)
  -- TODO: maybe, a setting which wire color to check
  if not station.valid then
    return contents
  end
  for _, wire in pairs({ defines.wire_type.red, defines.wire_type.green }) do
    local cn = station.get_circuit_network(wire)
    -- cn - signals (type,name),wire_type
    if cn ~= nil and cn.signals ~= nil then
      for _, signal_data in pairs(cn.signals) do
        if signal_data.signal.type == "virtual" and return_virtual ~= true then
          goto continue
        end
        table.insert(contents, {
          type = signal_data.signal.type,
          name = signal_data.signal.name,
          count = signal_data.count,
          color = colors[wire]
        })
        ::continue::
      end
    end
  end
  return contents
end

local function load_guess_pattern()
  refuel_pattern = split(settings.global["vtm-refuel-names"].value, ",")
  depot_pattern = split(settings.global["vtm-depot-names"].value, ",")
  requester_pattern = split(settings.global["vtm-requester-names"].value, ",")
  provider_pattern = split(settings.global["vtm-provider-names"].value, ",")
end

---comment Try to guess the station type: Requester, Provider, Depot or Refuel
---@param station LuaEntity
---@return string
local function guess_station_type(station)
  load_guess_pattern()
  local station_type = "ND"
  local is_refuel, is_depot, is_provider, is_requester
  local from_start = settings.global["vtm-p-or-r-start"].value

  -- depot
  for _, pattern in pairs(depot_pattern) do
    is_depot = string.find(string.lower(station.backer_name), pattern, 1, true) or false
    if is_depot then
      return "D"
    end
  end
  -- refuel
  for _, pattern in pairs(refuel_pattern) do
    is_refuel = string.find(string.lower(station.backer_name), pattern, 1, true) or false
    if is_refuel then
      return "F"
    end
  end
  -- requester
  for _, pattern in pairs(requester_pattern) do
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
  for _, pattern in pairs(provider_pattern) do
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

---comment extra sort criteria to sort depots tab
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

local function new_station(station)
  return {
    -- TODO: refine me, limit, avg
    force_index = station.force.index,
    station = station,
    created = game.tick,
    last_changed = game.tick,
    opened = "",
    closed = "",
    avg = 0, --TODO : calculate on finish log
    train_front_rail = nil,
    type = guess_station_type(station), -- one of P R D F or ND
    sort_prio = get_TCS_prio(station.backer_name),
    stock = {},
    in_transit = {},
  }
end

local function updated_station(station)
  return {
    -- TODO: refine me
    force_index = station.force.index,
    station = station,
    last_changed = game.tick,
    type = guess_station_type(station) or "", -- one of P R D F or ND
    sort_prio = get_TCS_prio(station.backer_name),
    -- stock = {},
    -- events = {}
  }
end

function vtm_logic.init_stations()
  if table_size(global.stations) > 0 then
    vtm_logic.update_all_stations("force")
    return
  end
  local train_stops = game.get_train_stops()
  local stations = {}
  load_guess_pattern()
  for _, station in pairs(train_stops) do
    stations[station.unit_number] = new_station(station)
  end
  global.stations = stations
end

-- unused, for now
function vtm_logic.update_station_limit(unit_number, entity)
  local station_data = global.stations[unit_number]
  if entity.station_limit < 1 then
    station_data.closed = game.tick
  elseif entity.station_limit > 0 and entity.station_limit < constants.MAX_LIMIT then
  end
end

function vtm_logic.update_station(station)
  -- special function for for_n_of
  if global.stations[station.unit_number] then
    global.stations[station.unit_number] = updated_station(station)
  else
    global.stations[station.unit_number] = new_station(station)
  end
  -- global.stations[station.unit_number].stock = read_station_network(station)
  return station.unit_number, true
end

---@param mode string
function vtm_logic.update_all_stations(mode)
  if mode == "force" then

    local train_stops = game.get_train_stops()
    load_guess_pattern()
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

local function clear_older_force(force_index, older_than)
  global.history = tables.filter(global.history, function(v)
    return v.force_index ~= force_index or v.last_change >= older_than
  end, true)
end

function vtm_logic.clear_older(player_index, older_than)
  local force_index = game.players[player_index].force.index
  clear_older_force(force_index, older_than)
end

local function find_first_stop(schedule)
  -- search for TCS signal
  local index = 1
  if schedule ~= nil and schedule.records and game.active_mods["Train_Control_Signals"] then
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
  return index

end

local function new_current(train)
  return {
    -- Required because front_stock might not be valid later
    force_index = train.front_stock.force.index,
    train = train,
    started_at = game.tick,
    last_change = game.tick,
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
    global.trains[train_id] = new_current(train)
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
  table.insert(global.history, 1, train_data)
  local new_data = new_current(train)
  global.trains[train_id] = new_data
  clear_older_force(new_data.force_index, game.tick - MAX_KEEP)
  -- log(serpent.block(train_data)) --FIXME: remove line
end

-- local interesting_states = {
--   [defines.train_state.path_lost] = true,
--   [defines.train_state.no_schedule] = true,
--   [defines.train_state.no_path] = true,
--   [defines.train_state.wait_signal] = false,
--   [defines.train_state.arrive_station] = true,
--   [defines.train_state.wait_station] = true,
--   [defines.train_state.manual_control_stop] = true,
--   [defines.train_state.manual_control] = true,
--   [defines.train_state.destination_full] = true
-- }

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
  -- TODO: check for Depot station
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
    -- end old entry, but save timestamp somewhere
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
      event.new_state == defines.train_state.on_the_path
  then
    log.old_tick = train_data.last_change
  end
  -- for train cargo in transit
  if train.has_path and train.path_end_stop then
    train_data.path_end_stop = train.path_end_stop.unit_number
  else
    train_data.path_end_stop = nil
  end
  add_log(train_data, log)

end

local function on_trainstop_build(event)
  if event.created_entity.name == "train-stop" then
    -- add_new_station(event.entity)
    game.print("build trainstop " .. event.created_entity.backer_name)
    -- create ne stop only if it has proper type
    local station_data = new_station(event.created_entity)
    if station_data.type ~= "ND" then
      global.stations[event.created_entity.unit_number] = station_data
    end
  end

end

local function on_trainstop_renamed(event)
  if event.entity.type == "train-stop" and event.by_script == false then
    local station_data = global.stations[event.entity.unit_number]
    load_guess_pattern()
    if station_data then
      station_data.type = updated_station(event.entity).type
        station_data.sort_prio = get_TCS_prio(event.entity.backer_name)
    else
      global.stations[event.entity.unit_number] = new_station(event.entity)
    end
    if not event.player_index then
      event.player_index = event.entity.last_user.index
    end
    script.raise_event(constants.refresh_event, {
      event = event,
      player_index = event.player_index
    })
    local force = event.entity.last_user.force
    force.print("Trainstop renamed " .. event.entity.backer_name)
  end

end

local function on_train_schedule_changed(event)
  local train = event.train
  local train_id = train.id
  if not event.player_index then
    return
  end
  -- local train_data = get_train_data(train, train_id)
  -- add_log(train_data, {
  --   tick = game.tick,
  --   schedule = train.schedule,
  --   changed_by = event.player_index
  -- })
  -- TODO trigger station refresh from train path_end_stop :/
  -- worth nothing if there is nothing ready to deliver
  -- better make that available in a different way

end

-- EVENTS

script.on_event(defines.events.on_train_changed_state, function(event)
  on_train_changed_state(event)
end)

script.on_event(defines.events.on_train_schedule_changed, function(event)
  on_train_schedule_changed(event)
end)

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
