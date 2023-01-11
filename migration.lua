local mod_gui_button = require("scripts.gui.mod_gui_button")

local function add_mod_gui_buttons()
    for _, player in pairs(game.players) do
        if player.valid then
            mod_gui_button.add_mod_gui_button(player)
        end
    end
end

return {
  add_mod_gui_buttons = add_mod_gui_buttons
}