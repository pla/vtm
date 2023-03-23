local constants = require("__vtm__.scripts.constants")
local styles = data.raw["gui-style"]["default"]

styles.vtm_main_content_frame = {
  type = "frame_style",
  parent = "deep_frame_in_shallow_frame",
  height = constants.gui_content_frame_height,
  horizontally_stretchable = "on",
}

styles.vtm_searchbar_frame = {
  type = "frame_style",
  parent = "inside_shallow_frame_with_padding",
  padding = 8,
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
    },
  },
}

styles.vtm_table_row_frame = {
  type = "frame_style",
  horizontally_stretchable = "on",
  parent = "statistics_table_item_frame",
  horizontal_flow_style = {
    type = "horizontal_flow_style",
    vertical_align = "center",
    horizontally_stretchable = "on",
  },
}

styles.vtm_list_box_row_frame = {
  type = "frame_style",
  parent = "subheader_frame",
  graphical_set = styles.list_box_item.graphical_set,
  padding = 1,
  horizontally_stretchable = "on",
  horizontally_squashable = "on",
  horizontal_flow_style = {
    type = "horizontal_flow_style",
    vertical_align = "center",
    horizontally_stretchable = "on",
  },
}
styles.vtm_bordered_frame_no_padding = {
  type = "frame_style",
  parent = "bordered_frame",
  padding = 0,
}

styles.vtm_minimap_frame = {
  type = "frame_style",
  parent = "train_with_minimap_frame",
  graphical_set = styles.deep_frame_in_shallow_frame.graphical_set,
}
-- SCROLL PANE STYLES
styles.vtm_list_box_scroll_pane = {
  type = "scroll_pane_style",
  parent = "list_box_scroll_pane",
  graphical_set = styles.scroll_pane_with_dark_background_under_subheader.graphical_set,
  vertical_flow_style = {
    type = "vertical_flow_style",
    vertical_spacing = 0,
    vertically_stretchable = "on",
    -- horizontally_stretchable = "on",
  },
}
-- the left listbox style scroll pane
styles.vtm_groups_list_box_scroll_pane = {
  type = "scroll_pane_style",
  parent = "list_box_scroll_pane",
  graphical_set = styles.flib_naked_scroll_pane.graphical_set,
  width = 300,
  vertical_flow_style = {
    type = "vertical_flow_style",
    vertical_spacing = 0,
    vertically_stretchable = "on",
  },
}


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

-- label styles
styles.vtm_clickable_semibold_label = {
  type = "label_style",
  parent = "clickable_label",
  font = "default-semibold",
}
styles.vtm_clickable_semibold_label_with_padding = {
  type = "label_style",
  parent = "clickable_label",
  font = "default-semibold",
  left_padding = 8,
}

styles.vtm_semibold_label = {
  type = "label_style",
  font = "default-semibold",
}

styles.vtm_semibold_label_with_padding = {
  type = "label_style",
  font = "default-semibold",
  left_padding = 8,
}

styles.vtm_trainid_label = {
  type = "label_style",
  vertical_align = "bottom",
  horizontal_align = "right",
  font = "default-semibold",
  parent = "label",
  size = 32,
}
-- minimap
styles.vtm_minimap_label = {
  type = "label_style",
  font = "default-game",
  font_color = default_font_color,
  size = constants.gui.groups_tab.map,
  vertical_align = "bottom",
  horizontal_align = "right",
  right_padding = 4,
}

styles.vtm_minimap_button = {
  type = "button_style",
  parent = "button",
  size = constants.gui.groups_tab.map,
  default_graphical_set = {},
  hovered_graphical_set = {},
  clicked_graphical_set = { position = { 70, 146 }, size = 1, opacity = 0.7 },
}

--switch
styles.vtm_subheader_switch = {
  type = "switch_style",
  parent = "switch",
  inactive_label = {
    type = "label_style",
    parent = "subheader_caption_label"
  },
  active_label = {
    type = "label_style",
    parent = "subheader_caption_label",
    font_color = { 0.945098, 0.745098, 0.392157 }
  }
}

-- button
styles.vtm_list_box_item = {
  type = "button_style",
  parent = "list_box_item",
  horizontally_stretchable = "on",
  horizontally_squashable = "on",
}

-- style for the group edit window
styles.vtm_list_box_button = {
  type = "button_style",
  parent = "list_box_item",
  height = 28,
  font = "default-bold",
  default_font_color = bold_font_color,
}

local btn = styles.button

styles.vtm_list_box_item_selected = {
  type = "button_style",
  parent = "vtm_list_box_item",
  default_font_color = btn.selected_font_color,
  default_graphical_set = btn.selected_graphical_set,
  hovered_font_color = btn.selected_hovered_font_color,
  hovered_graphical_set = btn.selected_hovered_graphical_set,
  clicked_font_color = btn.selected_clicked_font_color,
  clicked_graphical_set = btn.selected_clicked_graphical_set,
  -- Simulate clicked-vertical-offset
  -- top_padding = 1,
  -- bottom_padding = -1,
}
