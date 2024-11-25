local tables     = require("__flib__.table")
-- local gui         = require("__flib__.gui")
local gui        = require("__virtm__.scripts.flib-gui")
local gui_util   = require("__virtm__.scripts.gui.utils")
local constants  = require("__virtm__.scripts.constants")
local match      = require("__virtm__.scripts.match")
local format     = require("__flib__.format")

local inv_states = tables.invert(defines.space_platform_state)

local space      = {}

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

function space.update_tab(gui_id)
  local vtm_gui = storage.guis[gui_id]
  local surface = storage.settings[storage.guis[gui_id].player.index].surface or "All"
  local inv_trains = {}
  local table_index = 0
  local max_lines = storage.max_lines
  local filters = {
    -- item = vtm_gui.gui.filter.item.elem_value.name,
    -- fluid = vtm_gui.gui.filter.fluid.elem_value,
    search_field = vtm_gui.gui.filter.search_field.text:lower(),
  }
  -- luaforce.platforms
  -- gather data, speed > 0 , unterwegs nach schedule current
  -- speed * 60 = km/s
  local platforms = {}
  for key, platform in pairs(vtm_gui.player.force.platforms) do
    if platform.valid then
      ---@type PlatformData
      local p = {
        key = platform.index,
        name = platform.name,
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

  --update gui
  local scroll_pane = vtm_gui.gui.space.scroll_pane or {}
  local children = scroll_pane.children
  local width = constants.gui.space

  for _, p in pairs(platforms) do
    if table_index >= max_lines and
        max_lines > 0 and
        storage.settings[vtm_gui.player.index].gui_refresh == "auto" and
        filters.search_field == ""
    then
      -- max entries
      break
    end

    table_index = table_index + 1
    vtm_gui.gui.space.warning.visible = false
    -- get or create gui row
    local row = children[table_index]
    if not row then
      row = gui.add(scroll_pane, {
        type = "frame",
        direction = "horizontal",
        style = "vtm_table_row_frame",
        {
          type = "label",
          style = "vtm_semibold_label_with_padding",
          tooltip = { "vtm.space-open" },
          style_mods = { width = width.name },
        },
        {
          type = "label",
          style = "vtm_semibold_label_with_padding",
          style_mods = { width = width.status },
        },
        {
          type = "label",
          style = "vtm_semibold_label_with_padding",
          style_mods = { width = width.location },
        },
        {
          type = "label",
          style = "vtm_semibold_label_with_padding",
          style_mods = { width = width.weight, horizontal_align = "right"},
        },
        gui_util.slot_table(width, nil, "cargo"),
      })
    end

    local status_string = "platform_status_message(p)"

    gui.update(row, {
      {
        elem_mods = {
          caption = p.name,
          tooltip = { "vtm.space-open" },
        },
        actions = {
          on_click = { type = "space", action = "open-space", surface = p.key },
        },
      },
      {
        --status
        elem_mods = {
          caption = status_string,
          tooltip = { "", inv_states[p.state], " : ", p.state }
        }
      },
      {
        elem_mods = { caption = p.location or "Fixme" }
      },
      { 
        elem_mods = { caption = p.weight .. " t"}
      }
    })
    gui_util.slot_table_update_train(row.cargo_table, p.contents, vtm_gui.gui_id)
  end


  vtm_gui.gui.tabs.space_tab.badge_text = table_index
  if table_index == 0 then
    vtm_gui.gui.space.warning.visible = true
  end
  for child_index = table_index + 1, #children do
    children[child_index].destroy()
  end

end

function space.build_gui(gui_id)
  local width = constants.gui.space
  return {
    tab = {
      type = "tab",
      caption = { "vtm.tab-space" },
      ref = { "tabs", "space_tab" },
      name = "space",
      style_mods = { badge_horizontal_spacing = 6 },
      actions = {
        on_click = { type = "generic", action = "change_tab", tab = "space" },
      },
    },
    content = {
      type = "frame",
      style = "vtm_main_content_frame",
      direction = "vertical",
      ref = { "space", "content_frame" },
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
        ref = { "space", "scroll_pane" },
        vertical_scroll_policy = "always",
        horizontal_scroll_policy = "never",
      },
      {
        type = "frame",
        direction = "horizontal",
        style = "negative_subheader_frame",
        ref = { "space", "warning" },
        visible = true,
        {
          type = "flow",
          style = "compact_horizontal_flow",
          style_mods = { horizontally_stretchable = true },
          {
            type = "label",
            style = "bold_label",
            caption = { "", "[img=warning-white] ", { "vtm.no-platforms" } },
            ref = { "space", "warning_label" },
          },
        },
      },
    }
  }
end

---Handle gui actions
---@param action GuiAction
---@param event EventData.on_gui_click
function space.handle_action(action, event)
  if action.action == "open-space" then

  elseif action.action == "refresh" then
    -- trains.update_tab(action.gui_id)
  end
end

return space
