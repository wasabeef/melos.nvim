# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **melos 7.x (pub workspaces) support**: `pubspec.yaml` with a top-level `melos:` key is now automatically detected and used as the config source. melos 0.x–6.x projects using `melos.yaml` continue to work without any changes.
- **`config_file` option**: `setup({ config_file = 'auto'|'melos.yaml'|'pubspec.yaml' })` allows manual override of config file detection. Defaults to `'auto'`.
- **Extended script schema interpretation**: `run`, `steps`, `exec` (including `exec` as an object with `run`, `concurrency`, `failFast`, etc.), `env`, and `packageFilters` fields are now parsed. Description fallbacks are generated when `description` is absent.
- **Script group skipping (v7.3+)**: Entries with nested `scripts:` tables (script groups) are excluded from the picker with a single aggregated warning notification.
- **Abort warning for non-runnable scripts**: Selecting a script with `kind = 'unknown'` (no `run`, `steps`, or `exec`) in `:MelosRun` now emits a warning and aborts execution instead of running an empty command.
- **Info notification when scripts section is empty**: When the `scripts:` section is present but empty or null, an info-level notification is shown and the picker is not opened.
- **v7-aware CI**: GitHub Actions workflow (`.github/workflows/test.yml`) runs smoke tests against both v6 and v7 fixtures on every push/PR.

### Changed

- **Config file detection is now descriptor-based**: The parser detects `melos.yaml` vs `pubspec.yaml (melos:)` before executing `yq`, allowing precise query selection (`'.scripts'` for v6, `'.melos.scripts'` for v7).
- **`:MelosOpen` and `:MelosEdit` open the detected config file**: In v7 projects these commands operate on `pubspec.yaml` instead of `melos.yaml`.

### Fixed

- **Line lookup for quoted YAML keys**: `find_script_line_number` now recognizes `"key"` and `'key'` entries, so `:MelosEdit` jumps correctly for scripts whose names require quoting (e.g. `"build:apk"`).
- **Line lookup for quoted keys with YAML escapes**: The quoted-key scanner now honors `\"` / `\\` in double-quoted keys and `''` in single-quoted keys, so entries like `"say\"hi"` and `'say''bye'` resolve to the correct line number instead of 0.
- **Decode Unicode and control-character escapes in quoted keys**: Double-quoted scanner now recognizes `\n`, `\t`, `\xNN`, `\uNNNN`, and `\UNNNNNNNN`, encoding the result as UTF-8. Keys such as `"snowman \u2603"` or `"tab\there"` now line up with what yq emits in its JSON output.
- **Anchor detection with trailing comments**: `scripts: # comment` and `melos: # comment` (valid YAML) are now recognized as anchors, so `:MelosEdit` no longer falls back to opening the file at the top.
- **Duplicate notification when scripts section is empty**: The picker no longer emits a second generic `No melos scripts found.` message after the parser has already notified the specific cause.

## [0.1.1] - 2025-07-01

### Fixed

- Trim multi-line descriptions to single line in picker display.

## [0.1.0] - 2025-06-20

### Added

- Initial release: `:MelosRun`, `:MelosEdit`, `:MelosOpen` commands.
- Telescope picker integration.
- Floating terminal for script execution.
