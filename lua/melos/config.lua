-- lua/melos/config.lua
local M = {}

M.options = {
  terminal_width = 100, -- Default width of the floating terminal window
  terminal_height = 30, -- Default height of the floating terminal window
}

function M.setup(user_options)
  user_options = user_options or {}
  for key, value in pairs(user_options) do
    if M.options[key] ~= nil then
      M.options[key] = value
    else
      vim.notify(string.format("melos: Unknown option '%s'", key), vim.log.levels.WARN)
    end
  end
end

return M
