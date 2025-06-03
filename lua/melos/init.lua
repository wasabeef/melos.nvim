local picker = require("melos.picker") -- Changed from melos_nvim.picker
local config = require("melos.config") -- Changed from melos_nvim.config

local M = {}

--[[-
Initializes the melos.nvim plugin with user-provided options.
Delegates to `config.setup()`.
@param user_options table|nil A table containing user-defined options to override defaults.
                         See `lua/melos/config.lua` for available options.
--]]
function M.setup(user_options)
  config.setup(user_options)
end

--[[-
Shows a Telescope picker to select and run a Melos script.
This corresponds to the `:MelosRun` user command.
--]]
function M.run()
  picker.show_scripts({ action_type = "run" })
end

--[[-
Shows a Telescope picker to select a Melos script and jump to its
definition in the `melos.yaml` file.
This corresponds to the `:MelosEdit` user command.
--]]
function M.edit()
  picker.show_scripts({ action_type = "edit" })
end

--[[-
Opens the `melos.yaml` file located in the current working directory.
If the file does not exist, a notification is shown.
This corresponds to the `:MelosOpen` user command.
--]]
function M.open_file()
  local melos_yaml_path = vim.fn.getcwd() .. "/melos.yaml"
  local f = io.open(melos_yaml_path, "r")
  if f then
    f:close()
    vim.cmd("edit " .. vim.fn.fnameescape(melos_yaml_path))
    vim.notify("Opened " .. melos_yaml_path, vim.log.levels.INFO)
  else
    vim.notify("melos.yaml not found in the current directory.", vim.log.levels.ERROR)
  end
end

return M
