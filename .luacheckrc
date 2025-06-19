-- Luacheck configuration for Neovim plugin
std = "lua51"

-- Neovim globals
globals = {
  "vim",
}

-- Ignore certain warnings
ignore = {
  "212", -- unused argument
  "213", -- unused loop variable
  "631", -- line is too long
}

-- Exclude certain files
exclude_files = {
  "tests/",
  "doc/",
}

-- Neovim specific patterns
read_globals = {
  "vim",
}