
local flib_table     = require("__flib__.table")



local constants = {
  inv_platform_states = flib_table.invert(defines.space_platform_state),
  inv_train_tates = flib_table.invert(defines.train_state),
  gui_content_frame_height       = 700,
  gui_window_min_width           = 990,
  MAX_LIMIT                      = 4294967295,
  refresh_event                  = nil,
  group_exist_suffix             = "[img=utility/check_mark_green]",
  button_style_red               = "tool_button_red",
  button_style_green             = "tool_button_green",
  list_box_button_style          = "vtm_list_box_item",
  list_box_button_style_selected = "vtm_list_box_item_selected",
  blue                           = { 0, 0, 0.5, 0.5 },
}

constants.hidden_surfaces = {
  ["EE_TESTSURFACE_"] = true, -- Editor Extensions
  ["BPL_TheLab"] = true,      -- Blueprint Designer Lab
  ["bpsb-lab"] = true,        -- Blueprint Sandboxes
}

constants.gui = {
  trains = {
    train_id = 60,
    status = 374,
    since = 70,
    composition = 180,
    cargo = 36 * 6,
    cargo_columns = 6,
    appendix = 17,
  },
  space = {
    name = 200,
    status = 334,
    location = 80,
    weight = 70,
    cargo = 36 * 6,
    cargo_columns = 6,
    appendix = 17,
  },
  stations = {
    icon = 28,
    name = 283,
    status = 53,
    prio = 50,
    type = 50,
    stock = 36 * 5,
    stock_columns = 5,
    in_transit = 36 * 4,
    in_transit_columns = 4,
    appendix = 17,
  },
  depots = {
    name = 300,
    status = 200,
    trains = 200,
    type = 50,
    filler = 132,
    stock = 36 * 8,
    stock_columns = 8,
    colapse = 50,
    appendix = 17,
  },
  history = {
    train_id = 60,
    route = 454,
    switch = 150,
    depot = 160,
    runtime = 68,
    finished = 68,
    shipment = (36 * 5),
    shipment_columns = 5,
  },
  alerts = {
    time = 68,
    train_id = 60,
    route = 326,
    network_id = 84,
    type = 230,
    contents = 36 * 6,
  },
  groups = {
    window_min_width = 150,
    top_rows = 3,
    bottom_rows = 10,
    checkbox = 30,
    type = 10,
  },
  groups_tab = {
    group_list = 300,
    detail_list = 700,
    content_height = 308,
    icon = 28,
    name = 280,
    main_station_name = 164,
    map = 260,
    detail_frame = 270,
    member_name = 200,
    member_stock = 36 * 2,
    member_stock_columns = 2,
  },
}

constants.interesting_states = {
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
  [defines.train_state.on_the_path] = "gui-train-state.heading-to",
  [defines.train_state.no_schedule] = "gui-train-state.no-schedule",
  [defines.train_state.no_path] = "gui-train-state.no-path-to",
  [defines.train_state.arrive_signal] = "gui-train-state.heading-to",
  [defines.train_state.wait_signal] = "gui-train-state.heading-to",
  [defines.train_state.arrive_station] = "gui-train-state.heading-to",
  [defines.train_state.wait_station] = "gui-train-state.waiting-at",
  [defines.train_state.manual_control_stop] = "gui-train-state.manually-stopped",
  [defines.train_state.manual_control] = "gui-train-state.manually-driving",
  [defines.train_state.destination_full] = "gui-train-state.destination-full"
}

constants.state_description2 = {
  { defines.train_state.on_the_path,         { "vtm.train_state-on_the_path" } },
  { defines.train_state.no_schedule,         { "vtm.train_state-no_schedule" } },
  { defines.train_state.no_path,             { "vtm.train_state-no_path" } },
  { defines.train_state.arrive_signal,       { "vtm.train_state-arrive_signal" } },
  { defines.train_state.wait_signal,         { "vtm.train_state-wait_signal" } },
  { defines.train_state.arrive_station,      { "vtm.train_state-arrive_station" } },
  { defines.train_state.wait_station,        { "vtm.train_state-wait_station" } },
  { defines.train_state.manual_control_stop, { "vtm.train_state-manual_control_stop" } },
  { defines.train_state.manual_control,      { "vtm.train_state-manual_control" } },
  { defines.train_state.destination_full,    { "vtm.train_state-destination_full" } },
}

constants.wire_colors = {
  [defines.wire_connector_id.circuit_red] = "red",
  [defines.wire_connector_id.circuit_green] = "green",
}
constants.time_period_items = {
  {
      time = 60*2,
      text = "vtm.time-2m"
  },
  {
      time = 60*15,
      text = "vtm.time-15m"
  },
  {
      time = 60*60*1,
      text = "vtm.time-1h"
  },
  {
      time = 60*60*3,
      text = "vtm.time-3h"
  },
  {
      time = 60*60*6,
      text = "vtm.time-6h"
  },
  {
      time = 60*60*12,
      text = "vtm.time-12h"
  },
  {
      time = 60*60*24,
      text = "vtm.time-24h"
  }
}
constants.time_period_default_index = 2

return constants
