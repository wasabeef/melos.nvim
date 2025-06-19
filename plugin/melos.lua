local melos = require('melos')

--[[-
User command to list and run Melos scripts via a Telescope picker.
Invokes `melos.run()`.
--]]
vim.api.nvim_create_user_command('MelosRun', function()
  melos.run()
end, { desc = 'List and run Melos scripts' })

--[[-
User command to open melos.yaml and jump to a selected script definition.
Invokes `melos.edit()`.
--]]
vim.api.nvim_create_user_command('MelosEdit', function()
  melos.edit()
end, { desc = 'Open melos.yaml and jump to the selected script' })

--[[-
User command to open the melos.yaml file in the current project directory.
Invokes `melos.open_file()`.
--]]
vim.api.nvim_create_user_command('MelosOpen', function()
  melos.open_file()
end, { desc = 'Open melos.yaml in the current project' })
