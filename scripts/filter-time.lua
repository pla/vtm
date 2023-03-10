local tables = require("__flib__.table")

local time_period_items = {
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
local time_period_default_index = 2

local function ticks(time_period_index)
    return time_period_items[time_period_index].time * 60
end

return {
    time_period_items = tables.map(time_period_items, function(v) return {v.text} end),
    default_index = time_period_default_index,
    ticks = ticks
}