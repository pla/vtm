local constants = {}

constants.gui_content_frame_height = 700
constants.gui_content_frame_min_width = 900
constants.refresh_event=nil

-- constants.tabs = {
--   ["trains"] = {id=1,refresh="trains.update_tab"},
--   ["stations"] = {id=2,refresh="stations.update_tab"},
--   ["history"] = {id=3,refresh="trains.update_tab"},
--   ["summary"] ={id=4,refresh="trains.update_tab"},
-- }
-- local tab_order ={"trains", "stations","depots","history","statistic","events","summary"}
-- constants.tabs = {
--   ["trains"] = 1,
--   ["stations"] = 2,
--   ["depots"] = 3,
--   ["history"] = 4,
--   ["statistic"] = 5,
--   ["events"] = 6,
--   ["summary"] = 7,
-- }
constants.tabs = {}
-- content row width = 910, cant get stretch to work
constants.gui = {
  trains = {
    train_id = 60,
    status = 374,
    since = 70,
    composition = 180,
    cargo = 36 * 4,
    cargo_columns = 4,
    appendix = 17,
  },
  stations = {
    icon=40,
    name = 283,
    status = 53,
    since = 50,
    avg = 50,
    type = 50,
    stock = 36 * 5,
    stock_columns = 5,
    in_transit = 36 * 5,
    in_transit_columns = 5,
    appendix = 17,
  },
  depots = {
    name = 300,
    status = 200,
    trains = 200,
    type = 50,
    filler = 132,
    stock = 36 * 5,
    stock_columns = 5,
    colapse = 50,
    appendix = 17,
  },
  history = {
    train_id = 60,
    route = 292+160,
    depot = 160,
    runtime = 68,
    finished = 68,
    shipment = (36 * 6),
    shipment_checkbox_stretchy = true,
  },
  alerts = {
    time = 68,
    train_id = 60,
    route = 326,
    network_id = 84,
    type = 230,
    type_checkbox_stretchy = true,
    contents = 36 * 6,
  },

}

constants.station_type = {
  "P", --"Production",
  "D", -- "Depot",
  "R", --"Requester",
  "ND", -- "Other",
  "F" -- "Fuel"
}

constants.interesting_states = {
  [defines.train_state.path_lost] = true,
  [defines.train_state.no_schedule] = true,
  [defines.train_state.no_path] = true,
  [defines.train_state.wait_signal] = false,
  [defines.train_state.arrive_station] = true,
  [defines.train_state.wait_station] = true,
  [defines.train_state.manual_control_stop] = true,
  [defines.train_state.manual_control] = true,
  [defines.train_state.destination_full] = true
}

constants.state_description = {
  [defines.train_state.on_the_path] =  "gui-train-state.heading-to"  ,
  [defines.train_state.path_lost] =  "gui-train-state.no-path-to"  ,
  [defines.train_state.no_schedule] =  "gui-train-state.no-schedule"  ,
  [defines.train_state.no_path] =  "gui-train-state.no-path-to"  ,
  [defines.train_state.arrive_signal] =  "gui-train-state.standing-at"  ,
  [defines.train_state.wait_signal] =  "gui-train-state.heading-to"   ,
  [defines.train_state.arrive_station] =  "gui-train-state.standing-at"  ,
  [defines.train_state.wait_station] =  "gui-train-state.waiting-at"  ,
  [defines.train_state.manual_control_stop] =  "gui-train-state.manually-stopped"  ,
  [defines.train_state.manual_control] =  "gui-train-state.manually-driving"  ,
  [defines.train_state.destination_full] =  "gui-train-state.destination-full"
}

constants.state_description2 = {
  { defines.train_state.on_the_path, { "vtm.train_state-on_the_path" } },
  { defines.train_state.path_lost, { "vtm.train_state-path_lost" } },
  { defines.train_state.no_schedule, { "vtm.train_state-no_schedule" } },
  { defines.train_state.no_path, { "vtm.train_state-no_path" } },
  { defines.train_state.arrive_signal, { "vtm.train_state-arrive_signal" } },
  { defines.train_state.wait_signal, { "vtm.train_state-wait_signal" } },
  { defines.train_state.arrive_station, { "vtm.train_state-arrive_station" } },
  { defines.train_state.wait_station, { "vtm.train_state-wait_station" } },
  { defines.train_state.manual_control_stop, { "vtm.train_state-manual_control_stop" } },
  { defines.train_state.manual_control, { "vtm.train_state-manual_control" } },
  { defines.train_state.destination_full, { "vtm.train_state-destination_full" } },
}

constants.MAX_LIMIT = 4294967295
return constants
