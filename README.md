# melos.nvim

<div align="center">
  <p>
    <a href="https://github.com/wasabeef/melos.nvim/releases/latest">
      <img alt="Latest release" src="https://img.shields.io/github/v/release/wasabeef/melos.nvim" />
    </a>
  </p>
  <p>
    <a href="README.ja.md">日本語</a>
  </p>
</div>

`melos.nvim` is a Neovim plugin that allows you to easily list and execute scripts defined by [melos](https://melos.invertase.dev/), a monorepo management tool for Dart / Flutter projects.

https://github.com/user-attachments/assets/e69f5d74-9080-490e-b21f-d68502987f89

## Features

- Parses the `melos.yaml` of the current project and extracts the defined scripts.
- Clearly lists script names and optionally configured descriptions in the `telescope.nvim` interface.
- Selected scripts are executed in a customizable floating terminal, allowing you to check their output in real time.

## Requirements

- Neovim >= 0.7
- [nvim-telescope/telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- `yq` command-line tool (required for parsing `melos.yaml`)
  - See [yq documentation](https://mikefarah.gitbook.io/yq/#install) for installation instructions.

## Installation

Install using your preferred plugin manager.

### lazy.nvim

```lua
{
  "wasabeef/melos.nvim",
  dependencies = { "nvim-telescope/telescope.nvim" },
  config = function()
    require("melos").setup({
      -- Set the size of the floating terminal when executing scripts (optional)
      -- terminal_width = 100, -- Width (in characters)
      -- terminal_height = 30, -- Height (in lines)
    })
  end,
}
```

### packer.nvim

```lua
use {
  "wasabeef/melos.nvim", -- **Note**: Please replace this with your actual GitHub username or organization name.
  requires = { "nvim-telescope/telescope.nvim" },
  config = function()
    require("melos").setup({
      -- Set the size of the floating terminal when executing scripts (optional)
      -- terminal_width = 100,
      -- terminal_height = 30,
    })
  end,
}
```

## Usage

The plugin provides the following commands:

### `:MelosRun`

Displays the scripts defined in `melos.yaml` in the `telescope.nvim` picker.
Select a script and press `<Enter>` to execute the corresponding `melos` command in a floating terminal.

```vim
:MelosRun
```

### `:MelosEdit`

Displays the scripts defined in `melos.yaml` in the `telescope.nvim` picker.
Select a script, and `melos.yaml` will open with the cursor positioned at the selected script's definition.

```vim
:MelosEdit
```

### `:MelosOpen`

Opens the `melos.yaml` file for the current project directly.

```vim
:MelosOpen
```

### Keymapping Examples

```lua
-- In init.lua or related configuration files
vim.keymap.set('n', '<leader>mr', '<Cmd>MelosRun<CR>', { desc = 'Run Melos script' })
vim.keymap.set('n', '<leader>me', '<Cmd>MelosEdit<CR>', { desc = 'Edit Melos script in melos.yaml' })
vim.keymap.set('n', '<leader>mo', '<Cmd>MelosOpen<CR>', { desc = 'Open melos.yaml' })
```

## Configuration

You can configure the following options through the `setup` function.

- `terminal_width` (number, default: `100`): Width (in characters) of the floating terminal that opens when executing scripts.
- `terminal_height` (number, default: `30`): Height (in lines) of the floating terminal that opens when executing scripts.

Example:

```lua
require("melos").setup({
  terminal_width = 120,
  terminal_height = 40,
})
```

## Troubleshooting

- **If you see `yq: command not found` or a similar error:**
  - This plugin uses the `yq` command-line tool to parse `melos.yaml`.
  - Check if `yq` is installed on your system. If not, install it according to the [official yq documentation](https://mikefarah.gitbook.io/yq/#install).
- **If you see `melos: command not found` or a similar error:**
  - This plugin executes the `melos` command directly.
  - Check if `melos` is globally installed on your system or included in your project's `dev_dependencies` and executable (e.g., via `dart pub global run melos` or `flutter pub global run melos`).
  - See the [official Melos documentation](https://melos.invertase.dev/getting-started) for installation instructions.

## Contributing

Bug reports, feature requests, and Pull Requests are always welcome. Feel free to create an Issue or send a Pull Request.

## License

`melos.nvim` is released under the MIT License. See the `LICENSE` file for details.
