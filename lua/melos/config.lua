-- lua/melos/config.lua
local M = {}

--[[-
Default configuration options for the melos.nvim plugin.
Users can override these in their Neovim configuration.

@field terminal_width number Default width of the floating terminal window used for `MelosRun`.
@field terminal_height number Default height of the floating terminal window used for `MelosRun`.
--]]
M.options = {
  terminal_width = 100, -- Default width of the floating terminal window
  terminal_height = 30, -- Default height of the floating terminal window
}

--[[-
Sets up the plugin configuration by merging user-provided options with defaults.
Unknown options will be ignored and a warning will be issued.
@param user_options table|nil A table containing user-defined options to override defaults.
                         Example: `{ terminal_width = 120 }`
--]]
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
