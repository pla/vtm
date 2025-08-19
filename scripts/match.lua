-- match.lua
local match = {}

function match.filter_trains(result, filters)
  local matches_station = filters.search_field == ""
  if matches_station then
    return true
  end
  -- search the train schedule
  if result.train.valid and result.train.schedule then
    local schedule = result.train.schedule.records or {}
    for _, record in pairs(schedule) do
      if record.station then
        local search_field = record.station
        if search_field:lower():find(filters.search_field, 1, true) then
          matches_station = true
        end
      end
    end
  end
  if matches_station then
    return true
  end
  return false
end

function match.filter_history(result, filters)
  local matches_station = filters.search_field == ""
  if matches_station then
    -- no filters set
    return true
  end
  --search event log
  for _, event in pairs(result.events) do
    if not matches_station and event.station then
      local search_field = event.station.valid and event.station.backer_name or ""
      if search_field:lower():find(filters.search_field, 1, true) then
        matches_station = true
      end
    end
    if matches_station then
      return true
    end
  end
  return false
end

function match.filter_stations(station_data, filters)
  local matches_station = filters.search_field == ""
  if matches_station then
    -- no filters set
    return true
  end
  local search_field = station_data.station.valid and station_data.station.backer_name or ""
  if not matches_station and station_data.station then
    if search_field:lower():find(filters.search_field, 1, true) then
      matches_station = true
    end
  end
  if matches_station then
    return true
  end
  return false
end

function match.filter_group_set(set_name, filters)
  local matches_station = filters.search_field == ""
  if matches_station then
    -- no filters set
    return true
  end
  local search_string = set_name or ""
  if not matches_station then
    if search_string:lower():find(filters.search_field, 1, true) then
      matches_station = true
      return true
    end
  end
  return false
end

return match
