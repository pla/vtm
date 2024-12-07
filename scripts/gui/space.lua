local flib_table     = require("__flib__.table")
local flib_gui         = require("__flib__.gui")
local gui_utils   = require("__virtm__.scripts.gui.utils")
local constants  = require("__virtm__.scripts.constants")

local inv_states = flib_table.invert(defines.space_platform_state)

local space      = {}

--- @param gui_data GuiData
--- @param event EventData|EventData.on_gui_click
local function refresh(gui_data, event)
  script.raise_event(constants.refresh_event, {
    player_index = gui_data.player.index,
  })
end

local function platform_status_message(platform)
  -- TODO: Make it work [entity-status]
  --on-the-way=On the way
-- waiting-in-orbit=Waiting in Orbit
--waiting-at-stop=Waiting at stop
--no-path=No path
-- paused=Paused
--[gui-space-platforms]
--stopped-at=Stopped at __1__
end

function space.update_tab(gui_data, event)
  local surface = storage.settings[gui_data.player.index].surface or "All"
  local table_index = 0
  local max_lines = storage.max_lines
  local filters = {
    search_field = gui_data.gui.search_field.text:lower(),
  }
  -- luaforce.platforms
  -- gather data, speed > 0 , unterwegs nach schedule current
  -- speed * 60 = km/s
  local platforms = {}
  for key, platform in pairs(gui_data.player.force.platforms) do
    if platform.valid then
      ---@type PlatformData
      local p = {
        key = key,
        name = platform.name,
        surface_name = platform.surface.name,
        hub_position = platform.hub.position,
        weight = platform.weight / 1000, -- /1000 = tons
        contents = {} -- hub get_output_inventory get_contents
      }
      -- location
      if platform.space_location  then
        p.location = {"","[planet=", platform.space_location.name, "] "}
      else
        p.location = {"vtm.deep-space"} -- TODO -> from , to pictures
      end
      --schedule
      if platform.schedule then
        p.schedule = platform.schedule
      end
      platforms[p.key] = p
    end
  end
  if storage.settings[gui_data.player.index].current_tab ~= "space" then
    gui_data.gui.space.badge_text = table_size(platforms)
    return
  end


  --update gui
  local scroll_pane = gui_data.gui.space_scrollpane or {}
  local children = scroll_pane.children
  local width = constants.gui.space

  for _, p in pairs(platforms) do
    if table_index >= max_lines and
        max_lines > 0 and
        storage.settings[gui_data.player.index].gui_refresh == "auto" and
        filters.search_field == ""
    then
      -- max entries
      break
    end

    table_index = table_index + 1
    gui_data.gui.space_warning.visible = false
    -- get or create gui row
    local row = children[table_index]
    local refs = {}
    if not row then
      local gui_contents = {
        type = "frame",
        direction = "horizontal",
        style = "vtm_table_row_frame",
        {
          type = "label",
          name = "platform_name",
          style = "vtm_semibold_label_with_padding",
          tooltip = { "vtm.space-open" },
          style_mods = { width = width.name },
          handler = { [defines.events.on_gui_click] = space.open_space }
        },
        {
          type = "label",
          name = "platform_status",
          style = "vtm_semibold_label_with_padding",
          style_mods = { width = width.status },
        },
        {
          type = "label",
          name = "platform_location",
          style = "vtm_semibold_label_with_padding",
          style_mods = { width = width.location },
        },
        {
          type = "label",
          name = "platform_weight",
          style = "vtm_semibold_label_with_padding",
          style_mods = { width = width.weight, horizontal_align = "right"},
        },
        gui_utils.slot_table(width, nil, "cargo"),
      }
      refs, row = flib_gui.add(scroll_pane,gui_contents)
    end

      -- create refs for existing row
      if table_size(refs) == 0 then
        refs = gui_utils.recreate_gui_refs(row)
      end
    local status_string = "platform_status_message(p)"
      refs.platform_name.caption = p.name
      refs.platform_name.tags = flib_table.shallow_merge({ 
        refs.platform_name.tags,{ surface_name = p.surface_name, 
        position = p.hub_position }
      })
      refs.platform_status.caption = status_string
      refs.platform_status.tooltip = { "", inv_states[p.state], " : ", p.state }
      refs.platform_location.caption = p.location or "fixme"
      refs.platform_weight.caption = p.weight .. " t"

    gui_utils.slot_table_update_train(row.cargo_table, p.contents)
  end


  gui_data.gui.space.badge_text = table_index
  if table_index == 0 then
    gui_data.gui.space_warning.visible = true
  end
  for child_index = table_index + 1, #children do
    children[child_index].destroy()
  end

end

function space.build_gui()
  local width = constants.gui.space
  return {
    tab = {
      type = "tab",
      caption = { "vtm.tab-space" },
      name = "space",
      style_mods = { badge_horizontal_spacing = 6 },
    },
    content = {
      type = "frame",
      style = "vtm_main_content_frame",
      direction = "vertical",
      name = "space_content_frame",
      -- table header
      {
        type = "frame",
        style = "subheader_frame",
        direction = "horizontal",
        style_mods = { horizontally_stretchable = true },
        children = {
          {
            type = "label",
            style = "subheader_caption_label",
            caption = { "vtm.table-header-name" },
            style_mods = { width = width.name },
          },
          {
            type = "label",
            style = "subheader_caption_label",
            caption = { "vtm.table-header-status" },
            style_mods = { width = width.status },
          },
          {
            type = "label",
            style = "subheader_caption_label",
            caption = { "vtm.table-header-location" },
            style_mods = { width = width.location },
          },
          {
            type = "label",
            style = "subheader_caption_label",
            caption = { "vtm.table-header-weight" },
            style_mods = { width = width.weight },
          },
          {
            type = "label",
            style = "subheader_caption_label",
            caption = { "vtm.table-header-cargo" },
            style_mods = { width = width.cargo },
          },
        }
      },
      {
        type = "scroll-pane",
        style = "vtm_table_scroll_pane",
        name =  "space_scrollpane" ,
        vertical_scroll_policy = "always",
        horizontal_scroll_policy = "never",
      },
      {
        type = "frame",
        direction = "horizontal",
        style = "negative_subheader_frame",
        name = "space_warning",
        visible = true,
        {
          type = "flow",
          style = "compact_horizontal_flow",
          style_mods = { horizontally_stretchable = true },
          {
            type = "label",
            style = "bold_label",
            caption = { "", "[img=warning-white] ", { "vtm.no-platforms" } },
            name = "space_warning_label",
          },
        },
      },
    }
  }
end

--- @param gui_data GuiData
--- @param event EventData|EventData.on_gui_click
function space.open_space(gui_data, event)
  gui_utils.show_station(gui_data, event)
end

flib_gui.add_handlers(space, function(event, handler)
  local gui_id = gui_utils.get_gui_id(event.player_index)
  ---@type GuiData
  local gui_data = storage.guis[gui_id]
  if gui_data then
    handler(gui_data, event)
  end
end, "space")

return space
