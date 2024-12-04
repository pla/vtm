---@diagnostic disable: missing-fields
local data_util = require("__flib__.data-util")
require("__virtm__.prototypes.styles")

data:extend {
  {
    type = "sprite",
    name = "vtm_group_logo",
    layers = {
      {
        type = "sprite",
        filename = "__base__/graphics/icons/train-stop.png",
        position = { 0, 0 },
        size = 64,
        flags = { "icon" },
      },
      {
        type = "sprite",
        filename = "__core__/graphics/icons/technology/effect-constant/effect-constant-capacity.png",
        position = { 0, 0 },
        size = 64,
        -- scale="0.5",
        -- shift = { 8, 8 }
      },

    },
  },
  {
    type = "sprite",
    name = "vtm_refresh_white",
    layers = {
      {
        type = "sprite",
        filename = "__core__/graphics/refresh-white-animation.png",
        position = { 0, 0 },
        size = 32,
        flags = { "icon" },
      },
    },
  }
}


-- custom input
data:extend {
  {
    type = 'custom-input',
    name = 'vtm-key',
    key_sequence = 'SHIFT + T',
    enabled_while_spectating = false,
  },
  {
    type = 'custom-input',
    name = 'vtm-groups-key',
    key_sequence = 'SHIFT + G',
    enabled_while_spectating = false,
  },
  {
    type = "custom-input",
    name = "vtm-linked-focus-search",
    key_sequence = "",
    linked_game_control = "focus-search",
  },
}

-- shortcut
data:extend {

  {
    type                     = "shortcut",
    name                     = "vtm-shortcut",
    icon                     = "__virtm__/graphics/icons/shortcut.png",
    small_icon               = "__virtm__/graphics/icons/shortcut_white24.png",
    icon_size                = 32,
    small_icon_size          = 24,
    toggleable               = false,
    action                   = "lua",
    associated_control_input = "vtm-key",
  },
  {
    type                     = "shortcut",
    name                     = "vtm-groups-shortcut",
    icon                     = "__virtm__/graphics/icons/shortcutG.png",
    small_icon               = "__virtm__/graphics/icons/shortcutG.png",
    icon_size                = 32,
    small_icon_size          = 24,
    toggleable               = false,
    action                   = "lua",
    associated_control_input = "vtm-groups-key",
  },
}

-- selection tool
data:extend {

  {
    type = "selection-tool",
    name = "vtm-station-group-selector",
    subgroup = "tool",
    icons = {
      {
        icon = "__base__/graphics/icons/train-stop.png",
        icon_size = 32,
        -- tint = { r = 0.5, g = 0, b = 0, a = 0.5 } --red
      }
    },
    select = {
      border_color = { r = 0.72, g = 0.45, b = 0.2, a = 1 },
      mode = { "buildable-type", "same-force" },
      cursor_box_type = "entity",
      entity_type_filters = { "train-stop" },
    },
    alt_select = {
      border_color = { r = 0.72, g = 0.22, b = 0.1, a = 1 },
      mode = { "buildable-type", "same-force" },
      cursor_box_type = "entity",
      entity_type_filters = { "train-stop" },
    },
    flags = { "only-in-cursor", "spawnable" },
    stack_size = 1,
    hidden = true,
    -- selection_color = { r = 0.72, g = 0.45, b = 0.2, a = 1 },
    -- alt_selection_color = { r = 0.72, g = 0.22, b = 0.1, a = 1 },
    -- selection_mode = { "buildable-type", "same-force" },
    -- alt_selection_mode = { "buildable-type", "same-force" },
    -- selection_cursor_box_type = "entity",
    -- alt_selection_cursor_box_type = "entity",
    -- entity_type_filters = { "train-stop" },
    -- alt_entity_type_filters = { "train-stop" },
  },
}
