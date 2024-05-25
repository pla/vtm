--searchbar.lua
local constants = require("__vtm__.scripts.constants")
local vtm_logic = require("__vtm__.scripts.vtm_logic")
local tables = require("__flib__.table")
local queue = require("__flib__.queue")

local function refresh(action)
  script.raise_event(constants.refresh_event, {
    action = action,
    player_index = global.guis[action.gui_id].player.index
  })
end
---refresh surface drop down
---@param gui_id any
local function update(gui_id)
  local flow = global.guis[gui_id].gui.filter.surface_flow --[[@as LuaGuiElement]]
  local dropdown = global.guis[gui_id].gui.filter.surface --[[@as LuaGuiElement]]
  local surface = global.settings[global.guis[gui_id].player.index].surface or "All"
  local visible = global.surface_selector_visible --[[@as boolean]]
  if global.SE_active then
    visible = true
  end
  flow.visible = visible
  dropdown.clear_items()
  for _, value in pairs(global.surfaces) do
    dropdown.add_item(value)
  end
  -- Validate that the selected surface still exist
  local selected_index = tables.find(dropdown.items, global.surfaces[surface]) --[[@as uint]]
  -- If the surface was invalidated since last update, reset to all
  if not selected_index then
    selected_index = 1
    surface = "All"
  end
  dropdown.selected_index = selected_index
end

local function handle_action(action, event)
  local vtm = global.guis[action.gui_id]
  local gui = global.guis[action.gui_id].gui
  local filter_history = vtm.filter_history
  if action.action == "focus_search" then
    if gui and vtm.state == "open" and not vtm.pinned then
      gui.filter.search_field.focus()
      gui.filter.search_field.select_all()
    end
    return
  end
  if action.action == "apply-surface" then
    -- get the key/original name of the surface(only to have Nauvis with a captial N)
    local surface = tables.find(global.surfaces, event.element.items[event.element.selected_index])
    global.settings[event.player_index].surface = surface or "All"
    refresh(action)
    return
  end
  if action.action == "refresh" then
    refresh(action)
    return
  end
  local filter = action.filter
  if action.action == "filter" then
    if filter ~= "search_field" then
      gui.filter.item.elem_value = { type = action.filter, name = action.value }
      action.action = "apply-filter"
    end
  end
  if action.action == "prev-filter" then
    
    -- get history table
    if #filter_history > 0  then
    -- fetch last entry
    
    -- remove entry from history  
    end
    
  end
  if action.action == "apply-filter" then
    if filter ~= "search_field" then
      local filter_guis = gui.filter
      if not filter_guis.item.elem_value then
        filter_guis.search_field.text = ""
        return
      end
      local name = filter_guis.item.elem_value.name
      local type = filter_guis.item.elem_value.type
      filter_guis.search_field.text = "[" .. type .. "=" .. name .. "]"
      -- if event.button and event.button == defines.mouse_button_type.right then
      --   filter_guis.search_field.text = ("=" .. filter_guis.item.elem_value.name .. "]") or ""
      -- end
      table.insert(filter_history,1,filter_guis.search_field.text)
      while #filter_history > 10 do
        table.remove(filter_history,11)
      end
    end
    refresh(action)
    return
  end
  if action.action == "clear-filter" then
    if action.button and event.button ~= defines.mouse_button_type[action.button] then
      return
    end
    local filter_guis = gui.filter
    filter_guis.search_field.text = ""
    filter_guis.item.elem_value = nil
    refresh(action)
  end
end

local function build_gui(gui_id)
  return {
    type = "frame",
    direction = "horizontal",
    style = "vtm_searchbar_frame",
    -- style = "inside_shallow_frame_with_padding",
    children = {
      {
        -- search flow
        type = "flow",
        direction = "horizontal",
        style_mods = { vertical_align = "center", horizontal_spacing = 8 },
        children = {
          {
            type = "label",
            style = "vtm_semibold_label_with_padding",
            caption = { "gui.search" }
          },
          {
            type = "textfield",
            tooltip = { "vtm.filter-station-name-tooltip" },
            clear_and_focus_on_right_click = true,
            ref = { "filter", "search_field" },
            actions = {
              on_confirmed = {
                type = "searchbar",
                action = "apply-filter",
                gui_id = gui_id,
                filter = "search_field"
              },
              on_click = {
                type = "searchbar",
                action = "clear-filter",
                gui_id = gui_id,
                button = "right"
              }
            }
          },
          {
            type = "label",
            style = "vtm_semibold_label_with_padding",
            caption = { "gui.select-filter" }
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
                type = "searchbar",
                action = "apply-filter",
                gui_id = gui_id,
                filter = "item",
                button = "right"
              },
              on_click = {
                type = "searchbar",
                action = "clear-filter",
                gui_id = gui_id,
                button = "right"
              }
            }
          },
          {
            type = "button",
            style = "tool_button",
            caption = { "vtm.filter-prev" },
            tooltip = { "vtm.filter-prev-tooltip" },
            mouse_button_filter = { "left" },
            -- style_mods = { size = 28, },
            actions = {
              on_click = { type = "searchbar", action = "prev-filter", gui_id = gui_id }
            }
          },
          {
            type = "button",
            caption = { "vtm.filter-clear" },
            mouse_button_filter = { "left" },
            tooltip = { "vtm.filter-clear" },
            actions = {
              on_click = { type = "searchbar", action = "clear-filter", gui_id = gui_id }
            }
          },
        }
      }, -- end search flow
      {
        type = "empty-widget",
        style = "flib_horizontal_pusher",
      },
      {
        -- Surface flow
        type = "flow",
        direction = "horizontal",
        ref = { "filter", "surface_flow" },
        visible = false,
        style_mods = { vertical_align = "center", horizontal_align = "right", },
        children = {
          {
            type = "label",
            style = "vtm_semibold_label_with_padding",
            caption = { "vtm.filter-surface" }
          },
          {
            type = "drop-down",
            tooltip = { "vtm.filter-surface-tooltip" },
            ref = { "filter", "surface" },
            actions = {
              on_selection_state_changed = {
                type = "searchbar", action = "apply-surface", gui_id = gui_id,
              },
              -- on_click = {
              --   type = "searchbar", action = "clear-filter", gui_id = gui_id,
              -- }
            }
          },
        }
      } -- end surface flow
    }
  }
end

return {
  handle_action = handle_action,
  build_gui = build_gui,
  refresh = refresh,
  update = update,
}
