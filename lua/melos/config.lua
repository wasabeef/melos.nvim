--- @module melos.config
--- Configuration module for melos.nvim plugin
---
--- This module handles configuration management for the melos.nvim plugin,
--- providing default settings and allowing users to override them.
---
--- @author Daichi Furiya
--- @copyright 2025
--- @license MIT

local M = {}

--- @class MelosConfig
--- @field terminal_width number Width of the floating terminal window used for script execution
--- @field terminal_height number Height of the floating terminal window used for script execution

--- Default configuration options for the melos.nvim plugin
---
--- Users can override these options by passing a table to the setup() function.
--- All dimensions are in terminal cells (characters for width, lines for height).
---
--- @type MelosConfig
M.options = {
  terminal_width = 100, -- Default width of the floating terminal window
  terminal_height = 30, -- Default height of the floating terminal window
}

--- Set up the plugin configuration by merging user options with defaults
---
--- This function validates user-provided options and merges them with the
--- default configuration. Unknown options will be ignored and a warning
--- will be issued to help users identify potential typos.
---
--- @param user_options table|nil Table containing user-defined options to override defaults
---
--- @usage
--- require("melos.config").setup({
---   terminal_width = 120,
---   terminal_height = 40,
--- })
function M.setup(user_options)
  user_options = user_options or {}

  for key, value in pairs(user_options) do
    if M.options[key] ~= nil then
      M.options[key] = value
    else
      vim.notify(string.format("melos.nvim: Unknown option '%s'", key), vim.log.levels.WARN)
    end
  end
end

return M
