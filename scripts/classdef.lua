---@meta
--Alias definitions at the bottom

---@class GuiData
---@field gui_id uint
---@field gui table<string,LuaGuiElement>
---@field player LuaPlayer
---@field state string open or closed state of the main gui
---@field group_gui table<string,LuaGuiElement>?
---@field state_groups string open or closed state of the edit groups gui
---@field pinned boolean
---@field filter_history table Queue of previous search patterns

---@class PlayerSettings
---@field current_tab string
---@field surface string Surface name or All
---@field gui_refresh string for auto refresh
---@field history_switch string
---@field groups_tab_selected uint? selected group id in the groups tab
---@field groups_tab_pinned uint? pinned group id in the groups tab
---@field group_edit GroupEditData unit_number as key
---@field selected_group_set string? selected group in groups tab

---@class TrainData
---@field force_index uint
---@field train LuaTrain
---@field started_at uint
---@field last_change uint
---@field composition string Train composition
---@field prototype LuaEntityPrototype prototype of the loco
---@field sprite SpritePath icon of the loco
---@field contents { [string]: uint } Contents of the train, TODO check if needed
---@field events table<EventLog> Train state changed events get logged here for history
---@field surface string Surface where the train exits
---@field surface2 string Used when the train goes through a space elevator
---@field last_station LuaEntity the last station the train stopped
---@field path_end_stop uint unit_number of the station the train is heading for in transit

---@class HistoryData: TrainData
---@field shipment SlotTableDef

---@class StationData
---@field force_index uint
---@field station LuaEntity
---@field created uint
---@field last_changed uint
---@field opened uint? unused for now
---@field closed uint? unused for now
---@field sprite SpritePath
---@field train_front_rail LuaEntity Rail to check if a train is at station, still needed?
---@field type "P"|"R"|"D"|"F"|"H"|"ND" Station type Requester, Provider, Hidden, ND for undefined
---@field sort_prio uint used to manipulate the sort order of depots
---@field incoming_trains {[uint]:boolean} train_ids headed for the station
---@field stock SlotTableDef[] 
---@field stock_tick uint
---@field in_transit SlotTableDef[] unused for now
---@field registered_stock SlotTableDef[] 

---@class GuessPatterns
---@field depot table
---@field refuel table
---@field requester table
---@field provider table

---@class EventLog on_train_changed_state for history
---@field tick uint
---@field old_tick uint
---@field old_state uint last train_state
---@field state uint current train_state
---@field position MapPosition
---@field contents table train contents at the station
---@field fluids table fluid contents of the train at the station
---@field station LuaEntity station where the train is stopped
---@field diff table cargo change at the last station

---@class CustomEventDef Custom Refresh Event
---@field player_index uint
---@field action table

--- A dataset to put into a slot table.
---@class SlotTableDef
---@field type string item or fluid , virtual not in use
---@field name string prototype name of the item
---@field count number
---@field color string? color for the background of the slot, unused

---@class GroupData
---@field created uint
---@field surface string LuaSurface.name
---@field zoom float
---@field area BoundingBox this area contains all stations
---@field group_id uint unit_number of the Provider station
---@field main_station StationData
---@field members table<uint,StationData> key:unit numbers ,value:station_data excl the group_id
---@field resource_tags table<uint,LuaCustomChartTag> key:tag_number, resource tag eg. from yarm

---@class GroupEditData
---@field selected_group_id uint hold the id if dialog opened with group_id
---@field selected_stations table<uint,LuaEntity>|nil
---@field selected_tags table<uint,LuaCustomChartTag>|nil key:tag_number, resource tag eg. from yarm
---@field group_area BoundingBox
---@field show_overlay boolean
---@field add_to_selection boolean should newly selected stations be added
---@field removed table<uint>|nil Unit numbers of the last remove action
---@field provider table<uint,LuaEntity> Provider stations in selection to check for exiting groups

---@class GuiAction
---@field gui_id uint
---@field type string?
---@field action string?
---@field group_id uint?
---@field group_set string?
---@field surface_name string?
---@field position MapPosition?
---@field station_id uint?
---@field train_id uint?

---@alias unit_number uint Unit number of a LuaEntity
---@alias gui_id uint Interal number to access gui data and corresponding LuaPlayer
---@alias force_index uint LuaForce index
---@alias player_index uint LuaPlayer index
---@alias train_id uint id of LuaTrain

---@alias group_id uint Unit number of the main station of the group
---@alias set_name string Backer_name of the main station
---@alias GroupSet {[set_name]:table<group_id>} Key is the backer_name of the main station

---@alias GlobalGuis {[gui_id]:GuiData}
---@alias GlobalTrainData {[train_id]:TrainData}
---@alias GlobalHistoryData {[uint]:HistoryData}
---@alias GlobalStationData {[unit_number]:StationData}
---@alias GlobalPlayerSettings {[player_index]:PlayerSettings}
---@alias GlobalGroups {[force_index]:{[group_id]:GroupData}}

--- @class on_train_teleported
--- @field train LuaTrain
--- @field old_train_id_1 uint?
--- @field old_surface_index uint

--[[


  ---@type {[uint]:{[uint]:GroupData}}
  global.groups = {}


]]