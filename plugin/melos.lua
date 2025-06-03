vim.api.nvim_create_user_command(
  "MelosRun",
  function()
    require("melos").run() -- Changed from melos_nvim
  end,
  { nargs = 0, desc = "Show and run Melos scripts" }
)
