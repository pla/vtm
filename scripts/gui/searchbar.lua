--searchbar.lua
local constants = require("__virtm__.scripts.constants")
local flib_gui  = require("__flib__.gui")
local gui_utils = require("__virtm__.scripts.gui.utils")

local searchbar = {}

local function refresh(gui_data, event)
  -- main_gui.dispatch_refresh(gui_data, event)
  script.raise_event(constants.refresh_event, {
    player_index = gui_data.player.index,
  })
end

---refresh surface drop down
---@param gui_data GuiData
function searchbar.update(gui_data)
  local flow = gui_data.gui.surface_flow --[[@as LuaGuiElement]]
  local dropdown = gui_data.gui.surface_dropdown --[[@as LuaGuiElement]]
  local surface = storage.settings[gui_data.player.index].surface or "All"
  local visible = storage.surface_selector_visible --[[@as boolean]]
  local selected_index = 1
  if storage.SE_active or storage.SA_active then
    visible = true
  end
  flow.visible = visible
  dropdown.clear_items()
  for key, value in pairs(storage.surfaces) do
    dropdown.add_item(value)
    if key == surface then
      selected_index = #dropdown.items
    end
  end
  -- Validate that the selected surface still exist
  -- If the surface was invalidated since last update, reset to all
  if not selected_index then
    selected_index = 1
    surface = "All"
  end
  dropdown.selected_index = selected_index
end

function searchbar.build_gui(gui_id)
  return {
    type = "frame",
    direction = "horizontal",
    style = "vtm_searchbar_frame",
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
            name = "search_field",
            tags = { button = "right" },
            handler = {
              [defines.events.on_gui_confirmed] = searchbar.apply_filter,
              [defines.events.on_gui_click] = searchbar.clear_filter --right button
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
            name = "choose_elem_button",
            style_mods = { size = 32, },
            elem_type = "signal",
            tooltip = { "vtm.filter-item-tooltip" },
            tags = { button = "right" },
            handler = {
              [defines.events.on_gui_elem_changed] = searchbar.apply_filter,
              [defines.events.on_gui_click] = searchbar.clear_filter --right button
            },
          },
          {
            type = "button",
            style = "tool_button",
            name = "prev_filter",
            caption = { "vtm.filter-prev" },
            mouse_button_filter = { "left" },
            tooltip = { "vtm.filter-prev-tooltip" },
            handler = { [defines.events.on_gui_click] = searchbar.prev_filter },
          },
          {
            type = "button",
            name = "clear_filter",
            caption = { "vtm.filter-clear" },
            mouse_button_filter = { "left" },
            tooltip = { "vtm.filter-clear" },
            tags = { button = "left" },
            handler = { [defines.events.on_gui_click] = searchbar.clear_filter },
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
        name = "surface_flow",
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
            name = "surface_dropdown",
            tooltip = { "vtm.filter-surface-tooltip" },
            handler = {
              [defines.events.on_gui_selection_state_changed] = searchbar.apply_surface
            },
          },
        }
      } -- end surface flow
    }
  }
end

--- @param gui_data GuiData
--- @param event EventData|EventData.on_gui_click|EventData.on_gui_confirmed|EventData.on_gui_elem_changed
function searchbar.apply_filter(gui_data, event)
  local filter_history = gui_data.filter_history
  local name, type
  if event.element.name ~= "search_field" then
    -- do nothing when right click (clears search on text and chooser)
    if gui_utils.mouse_button_filter(event.button, "right") then
      -- if event.button and event.button == defines.mouse_button_type.right then
      return
    end
    -- check filter tag (a sprite button was clicked)
    if event.element.tags ~= nil and event.element.tags.filter ~= nil then
      type = event.element.tags.type --[[@as string]]
      name = event.element.tags.name --[[@as string]]
      -- open Factoriopedia when alt clicked
      if event.alt then
        if type == "item" then
        gui_data.player.open_factoriopedia_gui( prototypes.item[name] )
        elseif type == "fluid" then
          gui_data.player.open_factoriopedia_gui( prototypes.fluid[name] )
        else
          return
        end
      end
      -- set filter
      gui_data.gui.choose_elem_button.elem_value = {
        type = event.element.tags.type --[[@as string]],
        name = event.element.tags.name --[[@as string]],
        -- TODO add quality all around, maybe shift click to include quality
        -- quality = event.element.tags.quality or "normal"
      }
    end
    if event.element.name == "prev_filter" then
      type = gui_data.gui.choose_elem_button.elem_value.type or "item"  --[[@as string]]
      name = gui_data.gui.choose_elem_button.elem_value.name --[[@as string]]
    end
    -- choose elem button was used
    if event.element.name == "choose_elem_button" then
      if event.element.elem_value == nil then
        -- clearing the filter
        return
      end
      name = event.element.elem_value.name
      type = event.element.elem_value.type or "item" -- nil when "item"
      --TODO add quality
    end
    gui_data.gui.search_field.text = "[" .. type .. "=" .. name .. "]"
    if #filter_history == 0 or (#filter_history > 0 and gui_data.gui.choose_elem_button.elem_value.name ~= filter_history[1].name) then
      table.insert(filter_history, 1, gui_data.gui.choose_elem_button.elem_value)
    end
    while #filter_history > 10 do
      table.remove(filter_history, 11)
    end
  end
  refresh(gui_data, event)
end

--- @param gui_data GuiData
--- @param event EventData|EventData.on_gui_click
function searchbar.prev_filter(gui_data, event)
  local filter_history = gui_data.filter_history

  -- check history table
  if #filter_history > 0 then
    if not gui_data.gui.choose_elem_button.elem_value or
        gui_data.gui.choose_elem_button.elem_value and gui_data.gui.choose_elem_button.elem_value.name ~= filter_history[1].name then
      -- set first entry to filter if different
      gui_data.gui.choose_elem_button.elem_value = filter_history[1]
      -- remove entry from history
      table.remove(filter_history, 1)
    else -- first is current
      if #filter_history > 1 then
        --set second entry if there is one
        gui_data.gui.choose_elem_button.elem_value = filter_history[2]
        -- remove two entries
        table.remove(filter_history, 1)
        table.remove(filter_history, 1)
      end
    end
    searchbar.apply_filter(gui_data, event)
  end
end

--- @param gui_data GuiData
--- @param event EventData|EventData.on_gui_click
function searchbar.clear_filter(gui_data, event)
  if event.button and event.element.tags and event.button ~= defines.mouse_button_type[event.element.tags.button] then
    return
  end
  gui_data.gui.search_field.text = ""
  gui_data.gui.choose_elem_button.elem_value = nil
  refresh(gui_data, event)
end

--- @param gui_data GuiData
--- @param event EventData|EventData.on_gui_selection_state_changed
function searchbar.apply_surface(gui_data, event)
  local surface = "All"
  if event.element.items[event.element.selected_index][3] then
    surface = event.element.items[event.element.selected_index][3] --[[@as string]]
  else
    surface = event.element.items[event.element.selected_index] --[[@as string]]
  end
  storage.settings[event.player_index].surface = surface
  refresh(gui_data, event)
end

--- @param gui_data GuiData
--- @param event EventData|EventData
function searchbar.linked_focus_search(gui_data, event)
  if gui_data.gui and gui_data.state == "open" and not gui_data.pinned then
    gui_data.gui.search_field.focus()
    gui_data.gui.search_field.select_all()
  end
end

flib_gui.add_handlers(searchbar, function(event, handler)
  local gui_id = gui_utils.get_gui_id(event.player_index)
  ---@type GuiData
  local gui_data = storage.guis[gui_id]
  if gui_data then
    handler(gui_data, event)
  end
end)

searchbar.events = {
  ["vtm-linked-focus-search"] = searchbar.linked_focus_search,

}
return searchbar
