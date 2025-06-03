local melos = require("melos")

vim.api.nvim_create_user_command("MelosRun", function()
  melos.run()
end, { desc = "List and run Melos scripts" })

vim.api.nvim_create_user_command("MelosEdit", function()
  melos.edit()
end, { desc = "Open melos.yaml and jump to the selected script" })

vim.api.nvim_create_user_command("MelosOpen", function()
  melos.open_file()
end, { desc = "Open melos.yaml in the current project" })
