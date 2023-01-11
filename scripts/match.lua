-- match.lua
local match = {}

local function matches_filter(result, filters)
  -- if result.last_change < filters.time_period then
  --   return false
  -- end

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
      if search_field:lower():find(filters.search_field, 1, true) then
        matches_station = true
      end
    end
    if matches_item and matches_fluid and matches_station then
      return true
    end
  end
  return false
end

function match.filter_trains(result, filters)

  local matches_station = filters.search_field == ""
  if matches_station then
    return true
  end
  for _, event in pairs(result.events) do
    -- if not matches_item and event.contents then
    --   matches_item = event.contents[filters.item]
    -- end
    -- if not matches_fluid and event.fluids then
    --   matches_fluid = event.fluids[filters.fluid]
    -- end
    if not matches_station and event.station then
      local search_field = event.station.valid and event.station.backer_name or ""
      if search_field:lower():find(filters.search_field, 1, true) then
        matches_station = true
      end
    end
    if matches_station then
      return true
    end
    -- search the train schedule
    if result.train.valid and result.train.schedule then
      local schedule = result.train.schedule.records or {}
      for _, record in pairs(schedule) do
        if record.station:lower():find(filters.search_field, 1, true) then
          matches_station = true
        end
      end
    end
    if matches_station then
      return true
    end
  end
  return false
end

function match.filter_history(result, filters)

  local matches_station = filters.search_field == ""
  if matches_station then
    return true
  end
  for _, event in pairs(result.events) do
    -- if not matches_item and event.contents then
    --   matches_item = event.contents[filters.item]
    -- end
    -- if not matches_fluid and event.fluids then
    --   matches_fluid = event.fluids[filters.fluid]
    -- end
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
  -- local matches_item = filters.item == nil
  -- local matches_fluid = filters.fluid == nil
  local matches_station = filters.search_field == ""
  -- if matches_item and matches_fluid and matches_station then
  if matches_station then
    -- no filters set
    return true
  end
  local search_field = station_data.station.valid and
      station_data.station.backer_name or ""

  -- if not matches_item then
  --   if search_field:lower():find(filters.item, 1, true) then
  --     matches_item = true
  --   end
  -- end
  -- if not matches_fluid then
  --   if search_field:lower():find(filters.fluid, 1, true) then
  --     matches_fluid = true
  --   end
  -- end
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

return match
