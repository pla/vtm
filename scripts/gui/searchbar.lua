--searchbar.lua
local constants   = require("scripts.constants")
local time_filter = require("scripts.filter-time")
local vtm_logic   = require("scripts.vtm_logic")

local function refresh(action)
  script.raise_event(constants.refresh_event, {
    action = action,
    player_index = global.guis[action.gui_id].player.index
  })

end

local function handle_action(action, event)
  local vtm_gui = global.guis[action.gui_id]
  if action.action == "clear-older" then
    local older_than = game.tick - time_filter.ticks(vtm_gui.gui.filter.time_period.selected_index)
    local player = game.players[event.player_index]
    local force = player.force
    vtm_logic.clear_older(event.player_index, older_than)
    force.print { "vtm.player-cleared-history", player.name }
  end
  if action.action == "refresh" then
    refresh(action)
  end
  local filter = action.filter
  if action.action == "filter" then
    if filter == "item" and game.item_prototypes[action.value] then
      vtm_gui.gui.filter.item.elem_value = action.value
      action.action = "apply-filter"
    end
    if filter == "fluid" and game.fluid_prototypes[action.value] then
      vtm_gui.gui.filter.fluid.elem_value = action.value
      action.action = "apply-filter"
    end
  end
  if action.action == "apply-filter" then
    local filter_guis = vtm_gui.gui.filter
    if action.filter == "item" then
      filter_guis.fluid.elem_value = nil
      filter_guis.search_field.text = filter_guis.item.elem_value or ""
      if event.button and event.button == defines.mouse_button_type.right then
        filter_guis.search_field.text = ("=".. filter_guis.item.elem_value .. "]") or ""
      end
    elseif action.filter == "fluid" then
      filter_guis.item.elem_value = nil
      filter_guis.search_field.text = filter_guis.fluid.elem_value or ""
      if event.button and event.button == defines.mouse_button_type.right then
        filter_guis.search_field.text = ("=".. filter_guis.fluid.elem_value .. "]") or ""
      end

    end
    refresh(action)
  end
  if action.action == "clear-filter" then
    if action.button and event.button ~= defines.mouse_button_type[action.button] then
      return
    end
    local filter_guis = vtm_gui.gui.filter
    filter_guis.search_field.text = ""
    filter_guis.item.elem_value = nil
    filter_guis.fluid.elem_value = nil
    refresh(action)
  end
end

local function build_gui(gui_id)
  return {
    type = "frame",
    direction = "vertical",
    style = "inside_shallow_frame_with_padding",
    children = {
      {
        type = "flow",
        direction = "horizontal",
        style_mods = { vertical_align = "center", },
        children = {
          {
            type = "label",
            style = "vtm_semibold_label",
            caption = { "vtm.filter-search" }
          },
          {
            type = "textfield",
            tooltip = { "vtm.filter-station-name-tooltip" },
            clear_and_focus_on_right_click = true,
            ref = { "filter", "search_field" },
            actions = {
              on_confirmed = {
                type = "searchbar", action = "apply-filter", gui_id = gui_id,
                filter = "search_field"
              },
              on_click = {
                type = "searchbar", action = "clear-filter", gui_id = gui_id,
                button = "right"
              }
            }
          },
          {
            type = "label",
            style = "vtm_semibold_label",
            caption = { "vtm.filter-item-label" }
          },
          {
            type = "choose-elem-button",
            style = "slot_button_in_shallow_frame",
            style_mods = { size = 32, },
            elem_type = "item",
            tooltip = { "vtm.filter-item-tooltip" },
            ref = { "filter", "item" },
            actions = {
              on_elem_changed = {
                type = "searchbar", action = "apply-filter", gui_id = gui_id,
                filter = "item"
              }
            }
          },
          {
            type = "label",
            style = "vtm_semibold_label",
            caption = { "vtm.filter-or-fluid-label" }
          },
          {
            type = "choose-elem-button",
            style = "slot_button_in_shallow_frame",
            style_mods = { size = 32, },
            elem_type = "fluid",
            tooltip = { "vtm.filter-fluid-tooltip" },
            ref = { "filter", "fluid" },
            actions = {
              on_elem_changed = {
                type = "searchbar", action = "apply-filter", gui_id = gui_id,
                filter = "fluid"
              }
            }
          },
          {
            type = "button",
            caption = { "vtm.filter-clear" },
            tooltip = { "vtm.filter-clear" },
            actions = {
              on_click = { type = "searchbar", action = "clear-filter", gui_id = gui_id }
            }
          }
        }
      },
    }
  }
end

return {
  handle_action = handle_action,
  build_gui = build_gui,
  refresh = refresh,
}
