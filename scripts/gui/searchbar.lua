--searchbar.lua
local constants   = require("__vtm__.scripts.constants")
local time_filter = require("__vtm__.scripts.filter-time")
local vtm_logic   = require("__vtm__.scripts.vtm_logic")

local function refresh(action)
  script.raise_event(constants.refresh_event, {
    action = action,
    player_index = global.guis[action.gui_id].player.index
  })

end

local function handle_action(action, event)
  local vtm_gui = global.guis[action.gui_id]
  if action.action == "focus_search" then
    if vtm_gui and vtm_gui.state == "open" and not vtm_gui.pinned then
      vtm_gui.gui.filter.search_field.focus()
      vtm_gui.gui.filter.search_field.select_all()
    end
    return
  end
  if action.action == "refresh" then
    refresh(action)
    return
  end
  local filter = action.filter
  if action.action == "filter" then
    if filter ~= "search_field" then
      vtm_gui.gui.filter.item.elem_value = { type = action.filter, name = action.value }
      action.action = "apply-filter"
    end
  end
  if action.action == "apply-filter" then
    if filter ~= "search_field" then
      local filter_guis = vtm_gui.gui.filter
      if not filter_guis.item.elem_value then
        filter_guis.search_field.text = ""
        return
      end
      filter_guis.search_field.text = filter_guis.item.elem_value.name
      if event.button and event.button == defines.mouse_button_type.right then
        filter_guis.search_field.text = ("=" .. filter_guis.item.elem_value.name .. "]") or ""
      end
    end
    refresh(action)
    return
  end
  if action.action == "clear-filter" then
    if action.button and event.button ~= defines.mouse_button_type[action.button] then
      return
    end
    local filter_guis = vtm_gui.gui.filter
    filter_guis.search_field.text = ""
    filter_guis.item.elem_value = nil
    refresh(action)
  end
end

local function build_gui(gui_id)
  return {
    type = "frame",
    direction = "vertical",
    style = "inside_shallow_frame_with_padding",
    children = {
      { -- search flow
        type = "flow",
        direction = "horizontal",
        style_mods = { vertical_align = "center", },
        children = {
          {
            type = "label",
            style = "vtm_semibold_label_with_padding",
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
            style = "vtm_semibold_label_with_padding",
            caption = { "vtm.filter-item-label" }
          },
          {
            type = "choose-elem-button",
            style = "slot_button_in_shallow_frame",
            style_mods = { size = 32, },
            elem_type = "signal",
            tooltip = { "vtm.filter-item-tooltip" },
            ref = { "filter", "item" },
            actions = {
              on_elem_changed = {
                type = "searchbar", action = "apply-filter", gui_id = gui_id,
                filter = "item", button = "right"
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
      }, -- end search flow
    }
  }
end

return {
  handle_action = handle_action,
  build_gui = build_gui,
  refresh = refresh,
}
