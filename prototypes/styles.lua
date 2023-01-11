local constants = require("scripts.constants")
local styles = data.raw["gui-style"]["default"]

styles.vtm_main_content_frame = {
  type = "frame_style",
  parent = "deep_frame_in_shallow_frame",
  height = constants.gui_content_frame_height,
  horizontally_stretchable = "on",

}

styles.vtm_table_row_frame_light = {
  type = "frame_style",
  parent = "statistics_table_item_frame",
  top_padding = 8,
  bottom_padding = 8,
  left_padding = 8,
  right_padding = 8,
  minimal_width = 880,
  minimal_height = 52,
  horizontal_flow_style = {
    type = "horizontal_flow_style",
    vertical_align = "center",
    horizontal_spacing = 4,
    horizontally_stretchable = "on",
  },
  graphical_set = {
    base = {
      center = { position = { 76, 8 }, size = { 1, 1 } },
      -- bottom = {position = {8, 40}, size = {1, 8}},
    },
  },
}

styles.vtm_table_row_frame_dark = {
  type = "frame_style",
  parent = "vtm_table_row_frame_light",
  -- graphical_set = {
  --   base = {bottom = {position = {8, 40}, size = {1, 8}}},
  -- },
  graphical_set = {},
}

styles.vtm_table_row_frame = {
  type = "frame_style",
  horizontally_stretchable = "on",
  parent = "statistics_table_item_frame",
  horizontal_flow_style = {
    type = "horizontal_flow_style",
    vertical_align = "center",
    -- horizontal_spacing = 8,
    horizontally_stretchable = "on",
  },
}

-- SCROLL PANE STYLES

styles.vtm_table_scroll_pane = {
  type = "scroll_pane_style",
  parent = "flib_naked_scroll_pane_no_padding",
  vertical_flow_style = {
    type = "vertical_flow_style",
    vertically_stretchable = "on",
    horizontally_stretchable = "on",
    vertical_spacing = 0,
  },
}

styles.vtm_slot_table_scroll_pane = {
  type = "scroll_pane_style",
  parent = "flib_naked_scroll_pane_no_padding",
  horizontally_squashable = "off",
  background_graphical_set = {
    base = {
      position = { 282, 17 },
      corner_size = 8,
      overall_tiling_horizontal_padding = 4,
      overall_tiling_horizontal_size = 32,
      overall_tiling_horizontal_spacing = 8,
      overall_tiling_vertical_padding = 4,
      overall_tiling_vertical_size = 32,
      overall_tiling_vertical_spacing = 8,
    },
  },
}

-- TABBED PANE STYLES

styles.vtm_tabbed_pane = {
  type = "tabbed_pane_style",
  tab_content_frame = {
    type = "frame_style",
    parent = "tabbed_pane_frame",
    left_padding = 12,
    right_padding = 12,
    bottom_padding = 8,
  },
}

styles.vtm_small_slot_table_frame_light = {
  type = "frame_style",
  parent = "vtm_table_inset_frame_light",
  minimal_height = 36,
  background_graphical_set = {
    base = {
      position = { 282, 17 },
      corner_size = 8,
      overall_tiling_horizontal_padding = 4,
      overall_tiling_horizontal_size = 28,
      overall_tiling_horizontal_spacing = 8,
      overall_tiling_vertical_padding = 4,
      overall_tiling_vertical_size = 28,
      overall_tiling_vertical_spacing = 8,
    },
  },
}

styles.vtm_small_slot_table_frame_dark = {
  type = "frame_style",
  parent = "vtm_table_inset_frame_dark",
  minimal_height = 36,
  background_graphical_set = {
    base = {
      position = { 282, 17 },
      corner_size = 8,
      overall_tiling_horizontal_padding = 4,
      overall_tiling_horizontal_size = 28,
      overall_tiling_horizontal_spacing = 8,
      overall_tiling_vertical_padding = 4,
      overall_tiling_vertical_size = 28,
      overall_tiling_vertical_spacing = 8,
    },
  },
}

styles.vtm_slot_table_frame_light = {
  type = "frame_style",
  parent = "vtm_table_inset_frame_light",
  minimal_height = 40,
  background_graphical_set = {
    base = {
      position = { 282, 17 },
      corner_size = 8,
      overall_tiling_horizontal_padding = 4,
      overall_tiling_horizontal_size = 28,
      overall_tiling_horizontal_spacing = 8,
      overall_tiling_vertical_padding = 4,
      overall_tiling_vertical_size = 28,
      overall_tiling_vertical_spacing = 8,
    },
  },
}

styles.vtm_slot_table_frame_dark = {
  type = "frame_style",
  parent = "vtm_table_inset_frame_dark",
  minimal_height = 40,
  background_graphical_set = {
    base = {
      position = { 282, 17 },
      corner_size = 8,
      overall_tiling_horizontal_padding = 4,
      overall_tiling_horizontal_size = 28,
      overall_tiling_horizontal_spacing = 8,
      overall_tiling_vertical_padding = 4,
      overall_tiling_vertical_size = 28,
      overall_tiling_vertical_spacing = 8,
    },
  },
}

-- styles.vtm_table_right = {
--   type = "frame_style",
--   parent = "right_side_frame",
--   -- horizontally_stretchable = "on",
-- }

styles.vtm_table_inset_frame_light = {
  type = "frame_style",
  parent = "deep_frame_in_shallow_frame",
  horizontally_stretchable = "on",
}

styles.vtm_table_inset_frame_dark = {
  type = "frame_style",
  parent = "deep_frame_in_shallow_frame",
  graphical_set = {
    base = {
      position = { 51, 0 },
      corner_size = 8,
      center = { position = { 42, 8 }, size = { 1, 1 } },
      draw_type = "outer",
    },
    shadow = default_inner_shadow,
  },
}

styles.vtm_clickable_semibold_label = {
  type = "label_style",
  parent = "clickable_label",
  font = "default-semibold",
}

styles.vtm_semibold_label = {
  type = "label_style",
  -- parent = "default_label",
  font = "default-semibold",

}

styles.vtm_trainid_label = {
  type = "label_style",
  font_color = default_font_color,
  vertical_align = "bottom",
  horizontal_align = "right",
  font = "default-semibold",
  parent = "clickable_label",
  size = 32,

}
