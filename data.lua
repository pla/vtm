local data_util = require("__flib__.data-util")
local function create_sprite_icon(name, size)
  return {
    type = "sprite",
    name = "vtm_" .. name,
    filename = "__vtm__/graphics/icons/" .. name .. ".png",
    priority = "medium",
    width = size or 24,
    height = size or 24
  }
end
local function create_sprite_core(name, size,filename)
  return {
    type = "sprite",
    name = "vtm_" .. name,
    filename = filename,
    priority = "medium",
    width = size or 24,
    height = size or 24
  }
end

data:extend {
  create_sprite_icon("crosshairs-gps"),
  create_sprite_icon("train"),
  create_sprite_icon("timer-outline"),
  create_sprite_icon("train-36-white", 36),
  create_sprite_icon("vtm-logo-36", 36),
  create_sprite_icon("vtm-logo-48", 48),
  create_sprite_icon("icons8-trolley-32", 32),
  create_sprite_icon("refresh_black", 32),
  create_sprite_icon("refresh_white", 32),
}

data:extend {
  {
      type = 'custom-input',
      name = 'vtm-open',
      key_sequence = 'ALT + T',
      enabled_while_spectating = true,
  },
}
require("prototypes.styles")