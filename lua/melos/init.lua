--- @module melos
--- Main module for melos.nvim plugin
---
--- This module provides the main interface for the melos.nvim plugin,
--- which allows easy listing and execution of Melos scripts defined in melos.yaml.
---
--- @author Daichi Furiya
--- @copyright 2024
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
--- in the project's melos.yaml file. When a script is selected, it will be
--- executed in a floating terminal.
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
--- in the project's melos.yaml file. When a script is selected, the melos.yaml
--- file will be opened with the cursor positioned at the script's definition.
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

--- Open the melos.yaml file in the current working directory
---
--- This function opens the melos.yaml file located in the current working
--- directory. If the file does not exist, an error notification is displayed.
---
--- This corresponds to the :MelosOpen user command.
---
--- @usage
--- :MelosOpen
--- -- or in Lua:
--- require("melos").open_file()
function M.open_file()
  local melos_yaml_path = vim.fn.getcwd() .. '/melos.yaml'
  local f = io.open(melos_yaml_path, 'r')
  if f then
    f:close()
    vim.cmd('edit ' .. vim.fn.fnameescape(melos_yaml_path))
    vim.notify('Opened ' .. melos_yaml_path, vim.log.levels.INFO)
  else
    vim.notify('melos.yaml not found in the current directory.', vim.log.levels.ERROR)
  end
end

return M
