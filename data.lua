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

data:extend {
  create_sprite_icon("refresh_black", 32),
  create_sprite_icon("refresh_white", 32),
  create_sprite_icon("train"),
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
