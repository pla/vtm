local data_util = require("__flib__.data-util")
require("__vtm__.prototypes.styles")

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
  {
    type = "custom-input",
    name = "vtm-linked-focus-search",
    key_sequence = "",
    linked_game_control = "focus-search",
  },
  {
    type = "shortcut",
    name = "vtm-open",
    icon = data_util.build_sprite(nil, nil, "__vtm__/graphics/icons/shortcut.png", { 32, 32 }),
    small_icon = data_util.build_sprite(nil, nil, "__vtm__/graphics/icons/shortcut_black24.png", { 24, 24 }),
    disabled_small_icon  = data_util.build_sprite(nil, nil, "__vtm__/graphics/icons/shortcut_black24.png", { 24, 24 }),
    toggleable = false,
    action = "lua",
    associated_control_input = "vtm-open",
  },
}
