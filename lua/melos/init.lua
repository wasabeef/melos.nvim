--- @module melos
--- Main module for melos.nvim plugin
---
--- This module provides the main interface for the melos.nvim plugin,
--- which allows easy listing and execution of Melos scripts defined in melos.yaml.
---
--- @author Daichi Furiya
--- @copyright 2025
--- @license MIT

local config = require('melos.config')
local picker = require('melos.picker')

local M = {}

--- Initialize the melos.nvim plugin with user-provided options
---
--- This function sets up the plugin configuration by delegating to config.setup().
--- It should be called once during Neovim startup, typically in your init.lua
--- or plugin configuration.
---
--- @param user_options table|nil Optional table containing user-defined options to override defaults
---                              See lua/melos/config.lua for available configuration options
---
--- @usage
--- require("melos").setup({
---   terminal_width = 120,
---   terminal_height = 40,
--- })
function M.setup(user_options)
  config.setup(user_options)
end

--- Show a Telescope picker to select and run a Melos script
---
--- This function displays a Telescope picker containing all scripts defined
--- in the project's melos config file (melos.yaml or pubspec.yaml with melos key).
--- When a script is selected, it will be executed in a floating terminal.
---
--- This corresponds to the :MelosRun user command.
---
--- @usage
--- :MelosRun
--- -- or in Lua:
--- require("melos").run()
function M.run()
  picker.show_scripts({ action_type = 'run' })
end

--- Show a Telescope picker to select a Melos script and edit its definition
---
--- This function displays a Telescope picker containing all scripts defined
--- in the project's melos config file (melos.yaml or pubspec.yaml with melos key).
--- When a script is selected, the detected config file will be opened with the
--- cursor positioned at the script's definition.
---
--- This corresponds to the :MelosEdit user command.
---
--- @usage
--- :MelosEdit
--- -- or in Lua:
--- require("melos").edit()
function M.edit()
  picker.show_scripts({ action_type = 'edit' })
end

--- Open the detected melos config file (melos.yaml or pubspec.yaml) in the current working directory.
---
--- This corresponds to the :MelosOpen user command.
---
--- @usage
--- :MelosOpen
--- -- or in Lua:
--- require("melos").open_file()
function M.open_file()
  local desc = require('melos.parser').get_config_descriptor()
  if not desc then
    return
  end
  vim.cmd('edit ' .. vim.fn.fnameescape(desc.path))
  vim.notify('Opened ' .. desc.path, vim.log.levels.INFO)
end

return M
