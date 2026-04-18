# melos.nvim

<div align="center">
  <p>
    <a href="https://github.com/wasabeef/melos.nvim/releases/latest">
      <img alt="Latest release" src="https://img.shields.io/github/v/release/wasabeef/melos.nvim" />
    </a>
    <a href="https://codeassist.google/">
      <img alt="Gemini AI" src="https://img.shields.io/badge/Gemini%20AI-Code%20Assist-4796E3?style=flat&logo=google%20gemini&logoColor=white" />
    </a>
  </p>
  <p>
    <a href="README.ja.md">日本語</a>
  </p>
</div>

`melos.nvim` is a Neovim plugin that allows you to easily list and execute scripts defined by [melos](https://melos.invertase.dev/), a monorepo management tool for Dart / Flutter projects.

https://github.com/user-attachments/assets/b7185a4c-6aea-4a73-a02a-e5d9a5ddf456

## Features

- Supports **melos 6.x** (`melos.yaml`) and **melos 7.x** (`pubspec.yaml` with `melos:` key) automatically.
- Parses all script forms: plain string, `run`, `steps`, `exec` (including object form with `env`, `packageFilters`, etc.).
- Clearly lists script names and descriptions in the `telescope.nvim` interface. Missing descriptions are replaced with a generated fallback.
- Selected scripts are executed in a customizable floating terminal, allowing you to check their output in real time.
- Jump directly to a script's definition in the config file with `:MelosEdit`.
- Open the detected config file instantly with `:MelosOpen`.

## Requirements

- Neovim >= 0.7
- [nvim-telescope/telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- `yq` command-line tool (required for parsing config files)
  - See [yq documentation](https://github.com/mikefarah/yq/#macos--linux-via-homebrew) for installation instructions.
- **melos 6.x**: `melos.yaml` in the project root
- **melos 7.x**: `pubspec.yaml` with a top-level `melos:` key containing `scripts:`

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
      -- config_file = 'auto', -- 'auto' | 'melos.yaml' | 'pubspec.yaml'
    })
  end,
}
```

### packer.nvim

```lua
use {
  "wasabeef/melos.nvim",
  requires = { "nvim-telescope/telescope.nvim" },
  config = function()
    require("melos").setup({
      -- Set the size of the floating terminal when executing scripts (optional)
      -- terminal_width = 100,
      -- terminal_height = 30,
      -- config_file = 'auto',
    })
  end,
}
```

## Usage

The plugin provides the following commands:

### `:MelosRun`

Displays the scripts defined in the detected config file in the `telescope.nvim` picker.
Select a script and press `<Enter>` to execute the corresponding `melos` command in a floating terminal.

```vim
:MelosRun
```

### `:MelosEdit`

Displays the scripts defined in the detected config file in the `telescope.nvim` picker.
Select a script, and the config file (`melos.yaml` or `pubspec.yaml`) will open with the cursor positioned at the selected script's definition.

```vim
:MelosEdit
```

### `:MelosOpen`

Opens the detected config file (`melos.yaml` or `pubspec.yaml`) for the current project directly.

```vim
:MelosOpen
```

### Keymapping Examples

```lua
-- In init.lua or related configuration files
vim.keymap.set('n', '<leader>mr', '<Cmd>MelosRun<CR>', { desc = 'Run Melos script' })
vim.keymap.set('n', '<leader>me', '<Cmd>MelosEdit<CR>', { desc = 'Edit Melos script in config file' })
vim.keymap.set('n', '<leader>mo', '<Cmd>MelosOpen<CR>', { desc = 'Open Melos config file' })
```

## Configuration

You can configure the following options through the `setup` function.

- `terminal_width` (number, default: `100`): Width (in characters) of the floating terminal that opens when executing scripts.
- `terminal_height` (number, default: `30`): Height (in lines) of the floating terminal that opens when executing scripts.
- `config_file` (string, default: `'auto'`): Controls which config file the plugin reads.
  - `'auto'`: Auto-detect. Uses `melos.yaml` if present, otherwise `pubspec.yaml` with a `melos:` key. If both exist, `melos.yaml` takes precedence and a warning is shown.
  - `'melos.yaml'`: Always use `melos.yaml`. Shows an error if the file is not found.
  - `'pubspec.yaml'`: Always use `pubspec.yaml` and require a `melos:` key. Shows an error if the file is not found or the key is absent.
  - If an invalid value is passed, a warning is emitted and the plugin falls back to `'auto'`.

Example:

```lua
require("melos").setup({
  terminal_width = 120,
  terminal_height = 40,
  config_file = 'auto',
})
```

## melos 7.x (pub workspaces) Support

melos 7.x moves configuration into `pubspec.yaml`. The plugin detects the `melos:` key automatically. Example `pubspec.yaml`:

```yaml
name: my_workspace
environment:
  sdk: '>=3.9.0'

melos:
  scripts:
    build:
      description: 'Build APK'
      run: flutter build apk
    check:
      steps:
        - dart analyze
        - dart format --set-exit-if-changed .
    format:
      exec: dart format .
      packageFilters:
        dirExists: lib
    ci:
      description: 'CI pipeline'
      run: dart run ci_tool
      env:
        CI: 'true'
```

All script forms supported by melos 7.x are recognized: plain string, `run`, `steps`, `exec` (string or object), along with optional fields `env` and `packageFilters`.

## Limitations

- **Script groups (melos 7.3+)**: Entries with nested `scripts:` tables (script groups) are not expanded. They are excluded from the picker and a single aggregated warning notification is shown listing the skipped group names. Full group support is planned for a future release.
- **Scripts with no runnable command**: A script entry that contains only a `description` field (no `run`, `steps`, or `exec`) appears in the picker but cannot be executed. Selecting it in `:MelosRun` shows a warning and aborts.

## Troubleshooting

- **If you see `yq: command not found` or a similar error:**
  - This plugin uses the `yq` command-line tool to parse config files.
  - Check if `yq` is installed on your system. If not, install it according to the [official yq documentation](https://github.com/mikefarah/yq/#macos--linux-via-homebrew).
- **If you see `melos: command not found` or a similar error:**
  - This plugin executes the `melos` command directly.
  - Check if `melos` is globally installed on your system or included in your project's `dev_dependencies` and executable (e.g., via `dart pub global run melos` or `flutter pub global run melos`).
  - See the [official Melos documentation](https://melos.invertase.dev/getting-started) for installation instructions.
- **If you see `Neither melos.yaml nor pubspec.yaml(melos:) found in cwd`:**
  - The plugin could not find a valid config file in the current working directory.
  - For melos 6.x: ensure `melos.yaml` exists in the project root.
  - For melos 7.x: ensure `pubspec.yaml` contains a top-level `melos:` key with a `scripts:` section.
- **If you see `pubspec.yaml with melos: key not found` when using `config_file = 'pubspec.yaml'`:**
  - The `pubspec.yaml` is missing or does not contain a `melos:` key. Add the `melos:` section or switch `config_file` back to `'auto'`.

## Contributing

Bug reports, feature requests, and Pull Requests are always welcome. Feel free to create an Issue or send a Pull Request.

## License

`melos.nvim` is released under the MIT License. See the `LICENSE` file for details.
