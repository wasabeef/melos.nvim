local picker = require("melos.picker") -- Changed from melos_nvim.picker
local config = require("melos.config") -- Changed from melos_nvim.config

local M = {}

-- Setup function for users to pass settings
function M.setup(user_options)
  config.setup(user_options)
end

-- Main execution function
function M.run()
  picker.show_scripts({ action_type = "run" })
end

-- New function to handle editing melos.yaml
function M.edit()
  picker.show_scripts({ action_type = "edit" })
end

-- New function to simply open melos.yaml
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
