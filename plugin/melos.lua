local melos = require('melos')

--[[-
User command to list and run Melos scripts via a Telescope picker.
Invokes `melos.run()`.
--]]
vim.api.nvim_create_user_command('MelosRun', function()
  melos.run()
end, { desc = 'List and run Melos scripts' })

--[[-
User command to open the detected melos config file (melos.yaml or pubspec.yaml)
and jump to a selected script definition.
Invokes `melos.edit()`.
--]]
vim.api.nvim_create_user_command('MelosEdit', function()
  melos.edit()
end, { desc = 'Open the detected melos config file and jump to the selected script' })

--[[-
User command to open the detected melos config file (melos.yaml or pubspec.yaml)
in the current project directory.
Invokes `melos.open_file()`.
--]]
vim.api.nvim_create_user_command('MelosOpen', function()
  melos.open_file()
end, { desc = 'Open the detected melos config file in the current project' })
