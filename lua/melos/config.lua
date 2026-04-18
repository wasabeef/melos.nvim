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
--- @field config_file string Config file selection: 'auto'|'melos.yaml'|'pubspec.yaml'

--- Default configuration options for the melos.nvim plugin
---
--- @type MelosConfig
M.options = {
  terminal_width = 100,
  terminal_height = 30,
  config_file = 'auto', -- 'auto'|'melos.yaml'|'pubspec.yaml'
}

local ALLOWED_CONFIG_FILE = { auto = true, ['melos.yaml'] = true, ['pubspec.yaml'] = true }

--- Set up the plugin configuration by merging user options with defaults
---
--- @param user_options table|nil Options to override defaults. Supported keys:
---   - terminal_width (number)
---   - terminal_height (number)
---   - config_file ('auto'|'melos.yaml'|'pubspec.yaml') — invalid values fall back to 'auto' with a warning
function M.setup(user_options)
  user_options = user_options or {}

  for key, value in pairs(user_options) do
    if M.options[key] ~= nil then
      if key == 'config_file' and not ALLOWED_CONFIG_FILE[value] then
        vim.notify(
          string.format(
            "melos.nvim: invalid config_file '%s'. Allowed: auto|melos.yaml|pubspec.yaml. Falling back to 'auto'.",
            tostring(value)
          ),
          vim.log.levels.WARN
        )
        M.options[key] = 'auto'
      else
        M.options[key] = value
      end
    else
      vim.notify(string.format("melos.nvim: Unknown option '%s'", key), vim.log.levels.WARN)
    end
  end
end

return M
