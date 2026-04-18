--- @module melos.parser
--- YAML parsing module for melos.nvim plugin
---
--- Handles parsing of melos.yaml (v6) and pubspec.yaml with melos: key (v7).
--- Uses the 'yq' command-line tool for reliable YAML parsing.
---
--- @author Daichi Furiya
--- @copyright 2025
--- @license MIT

local M = {}

--- @private
local function file_exists(path)
  local f = io.open(path, 'r')
  if f then
    f:close()
    return true
  end
  return false
end

--- Check if pubspec.yaml contains a melos: key using yq.
--- Returns false (with WARN) on yq error — silent fallback is forbidden.
--- @param path string
--- @return boolean
--- @private
local function pubspec_has_melos_key(path)
  local cmd = string.format("yq e '.melos' -o=json %s", vim.fn.shellescape(path))
  local out = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify(
      'melos.nvim: failed to probe .melos key in '
        .. path
        .. ' (yq error). Falling back to melos.yaml detection. Output: '
        .. out,
      vim.log.levels.WARN
    )
    return false
  end
  local trimmed = out:gsub('%s+$', '')
  return trimmed ~= '' and trimmed ~= 'null'
end

--- @private
local function descriptor_v6(path)
  return {
    path = path,
    flavor = 'v6',
    yq_scripts_query = '.scripts',
    scripts_anchor = 'scripts',
    nested_key = nil,
  }
end

--- @private
local function descriptor_v7(path)
  return {
    path = path,
    flavor = 'v7',
    yq_scripts_query = '.melos.scripts',
    scripts_anchor = 'melos',
    nested_key = 'scripts',
  }
end

--- @class MelosConfigDescriptor
--- @field path string Absolute path to the config file
--- @field flavor 'v6'|'v7' v6: melos.yaml, v7: pubspec.yaml with melos: key
--- @field yq_scripts_query string yq query used to extract scripts (e.g. '.scripts' or '.melos.scripts')
--- @field scripts_anchor string Top-level YAML key to anchor on when searching line numbers
--- @field nested_key string|nil Sub-key under anchor for script entries (nil for v6, 'scripts' for v7)

--- Detect the config file and return a descriptor, or nil on failure.
---
--- Respects the `config_file` option ('auto'|'melos.yaml'|'pubspec.yaml').
--- In 'auto' mode, prefers melos.yaml over pubspec.yaml when both exist.
---
--- @return MelosConfigDescriptor|nil
local function get_config_descriptor()
  local cwd = vim.fn.getcwd()
  local melos_yaml = cwd .. '/melos.yaml'
  local pubspec = cwd .. '/pubspec.yaml'
  local option = require('melos.config').options.config_file or 'auto'

  if option == 'melos.yaml' then
    if file_exists(melos_yaml) then
      return descriptor_v6(melos_yaml)
    end
    vim.notify('melos.yaml not found (forced by config_file).', vim.log.levels.ERROR)
    return nil
  end

  if option == 'pubspec.yaml' then
    if file_exists(pubspec) and pubspec_has_melos_key(pubspec) then
      return descriptor_v7(pubspec)
    end
    vim.notify('pubspec.yaml with melos: key not found (forced by config_file).', vim.log.levels.ERROR)
    return nil
  end

  -- auto
  local has_melos_yaml = file_exists(melos_yaml)
  local has_pubspec_melos = file_exists(pubspec) and pubspec_has_melos_key(pubspec)

  if has_melos_yaml and has_pubspec_melos then
    vim.notify('Both melos.yaml and pubspec.yaml(melos:) exist. Using melos.yaml.', vim.log.levels.WARN)
    return descriptor_v6(melos_yaml)
  end
  if has_melos_yaml then
    return descriptor_v6(melos_yaml)
  end
  if has_pubspec_melos then
    return descriptor_v7(pubspec)
  end

  vim.notify('Neither melos.yaml nor pubspec.yaml(melos:) found in cwd.', vim.log.levels.ERROR)
  return nil
end

M.get_config_descriptor = get_config_descriptor

--- Extract script definitions from config file using yq.
---
--- @param desc table config descriptor
--- @return table|nil scripts JSON decoded table
--- @private
local function get_script_definitions_from_yq(desc)
  local cmd = string.format("yq e '%s' -o=json %s", desc.yq_scripts_query, vim.fn.shellescape(desc.path))
  local json_output = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    vim.notify('Failed to parse ' .. desc.path .. ' with yq. ' .. json_output, vim.log.levels.ERROR)
    return nil
  end

  local trimmed = json_output:gsub('%s+$', '')
  if trimmed == '' or trimmed == 'null' then
    return {}
  end

  local ok, scripts_json = pcall(vim.fn.json_decode, json_output)
  if not ok or type(scripts_json) ~= 'table' then
    vim.notify('Failed to decode yq JSON output. ' .. json_output, vim.log.levels.ERROR)
    return nil
  end
  return scripts_json
end

--- Truncate string to n chars, collapsing whitespace.
--- @param s any
--- @param n number
--- @return string
--- @private
local function truncate(s, n)
  if type(s) ~= 'string' then
    return ''
  end
  s = s:gsub('\n', ' '):gsub('%s+', ' ')
  if #s <= n then
    return s
  end
  return s:sub(1, n - 1) .. '…'
end

--- Returns true if value looks like a v7.3+ script group (not a runnable script).
--- @param value any
--- @return boolean
--- @private
local function is_group_like(value)
  if type(value) ~= 'table' then
    return false
  end
  -- Explicit group: has nested scripts table
  if type(value.scripts) == 'table' then
    return true
  end
  -- No runnable field and no description: treat as group if non-empty table
  local has_exec_field = value.run ~= nil or value.steps ~= nil or value.exec ~= nil
  local has_desc = type(value.description) == 'string' and value.description ~= ''
  if has_exec_field or has_desc then
    return false
  end
  return next(value) ~= nil
end

--- Normalize a single script entry. Returns nil when the entry is a group.
---
--- @param key string script key
--- @param value any raw yq value
--- @param group_collector table accumulates skipped group keys
--- @return table|nil script object
--- @private
local function normalize_script(key, value, group_collector)
  if is_group_like(value) then
    table.insert(group_collector, key)
    return nil
  end

  local desc, kind = '', 'unknown'

  if type(value) == 'string' then
    kind = 'string'
    desc = truncate(value, 40)
  elseif type(value) == 'table' then
    if type(value.description) == 'string' and value.description ~= '' then
      desc = value.description
    end
    if value.run ~= nil then
      kind = 'run'
      if desc == '' and type(value.run) == 'string' then
        desc = truncate(value.run, 40)
      end
    elseif value.steps ~= nil then
      kind = 'steps'
      if desc == '' and type(value.steps) == 'table' and type(value.steps[1]) == 'string' then
        desc = '[steps] ' .. truncate(value.steps[1], 32)
      end
    elseif value.exec ~= nil then
      kind = 'exec'
      if desc == '' then
        if type(value.exec) == 'string' then
          desc = '[exec] ' .. truncate(value.exec, 32)
        elseif type(value.exec) == 'table' and type(value.exec.run) == 'string' then
          desc = '[exec] ' .. truncate(value.exec.run, 32)
        else
          desc = '[exec]'
        end
      end
    end
  end

  return { name = key, description = desc, command = key, id = key, kind = kind }
end

--- Get line indent count for a line string.
--- @param line string
--- @return number
--- @private
local function line_indent(line)
  local spaces = line:match('^(%s*)')
  return spaces and #spaces or 0
end

--- Encode a Unicode code point as UTF-8 bytes. Returns nil for values
--- outside the valid Unicode range.
--- @param cp number
--- @return string|nil
--- @private
local function utf8_encode(cp)
  if cp < 0 or cp > 0x10FFFF then
    return nil
  end
  if cp < 0x80 then
    return string.char(cp)
  elseif cp < 0x800 then
    return string.char(0xC0 + math.floor(cp / 0x40), 0x80 + (cp % 0x40))
  elseif cp < 0x10000 then
    return string.char(0xE0 + math.floor(cp / 0x1000), 0x80 + (math.floor(cp / 0x40) % 0x40), 0x80 + (cp % 0x40))
  end
  return string.char(
    0xF0 + math.floor(cp / 0x40000),
    0x80 + (math.floor(cp / 0x1000) % 0x40),
    0x80 + (math.floor(cp / 0x40) % 0x40),
    0x80 + (cp % 0x40)
  )
end

-- Simple (single-char) escape map for YAML double-quoted scalars, restricted
-- to the subset that is safe to decode without a full YAML state machine.
-- Includes the YAML-specific escapes \N, \_, \L, \P which resolve to
-- Unicode code points rather than literal characters.
local SIMPLE_ESCAPES = {
  ['0'] = '\0',
  a = '\a',
  b = '\b',
  t = '\t',
  n = '\n',
  v = '\v',
  f = '\f',
  r = '\r',
  e = string.char(27),
  [' '] = ' ',
  ['"'] = '"',
  ['/'] = '/',
  ['\\'] = '\\',
  N = utf8_encode(0x85), -- NEL
  ['_'] = utf8_encode(0xA0), -- NBSP
  L = utf8_encode(0x2028), -- LS
  P = utf8_encode(0x2029), -- PS
}

--- Scan a double-quoted YAML scalar starting at `pos` (the opening `"`).
--- Decodes the common YAML 1.2 escapes so the resulting key matches what
--- yq emits in its JSON output (`\"`, `\\`, `\n`, `\t`, `\xNN`, `\uNNNN`,
--- `\UNNNNNNNN`, etc.). Returns nil on unterminated or malformed input.
--- @param line string
--- @param pos number index of the opening quote
--- @return string|nil key, number|nil close_pos
--- @private
local function scan_double_quoted(line, pos)
  local buf = {}
  local p = pos + 1
  local len = #line
  while p <= len do
    local c = line:sub(p, p)
    if c == '\\' then
      local nxt = line:sub(p + 1, p + 1)
      if nxt == '' then
        return nil
      end

      local simple = SIMPLE_ESCAPES[nxt]
      if simple then
        buf[#buf + 1] = simple
        p = p + 2
      elseif nxt == 'x' or nxt == 'u' or nxt == 'U' then
        local width = (nxt == 'x') and 2 or (nxt == 'u') and 4 or 8
        local hex = line:sub(p + 2, p + 1 + width)
        if #hex ~= width or hex:match('%X') then
          return nil
        end
        local encoded = utf8_encode(tonumber(hex, 16))
        if not encoded then
          return nil
        end
        buf[#buf + 1] = encoded
        p = p + 2 + width
      else
        -- Unknown escape: passthrough the trailing character so we keep
        -- making progress even on sequences we don't specifically handle.
        buf[#buf + 1] = nxt
        p = p + 2
      end
    elseif c == '"' then
      return table.concat(buf), p
    else
      buf[#buf + 1] = c
      p = p + 1
    end
  end
  return nil
end

--- Scan a single-quoted YAML scalar starting at `pos` (the opening `'`).
--- Honors the `''` escape for a literal `'`.
--- @param line string
--- @param pos number index of the opening quote
--- @return string|nil key, number|nil close_pos
--- @private
local function scan_single_quoted(line, pos)
  local buf = {}
  local p = pos + 1
  local len = #line
  while p <= len do
    local c = line:sub(p, p)
    if c == "'" then
      if line:sub(p + 1, p + 1) == "'" then
        buf[#buf + 1] = "'"
        p = p + 2
      else
        return table.concat(buf), p
      end
    else
      buf[#buf + 1] = c
      p = p + 1
    end
  end
  return nil
end

--- Extract the YAML mapping key from a line starting at `indent`.
--- Handles bare keys, double-quoted keys (with `\\` / `\"` escapes), and
--- single-quoted keys (with `''` escapes). Returns nil if the line is not
--- a mapping key entry.
--- @param line string raw line (no trailing CR)
--- @param indent number number of leading spaces to skip
--- @return string|nil extracted key
--- @private
local function extract_mapping_key(line, indent)
  local pos = indent + 1
  local first = line:sub(pos, pos)
  local key

  if first == '"' then
    local scanned, close_pos = scan_double_quoted(line, pos)
    if not scanned then
      return nil
    end
    key = scanned
    pos = close_pos + 1
  elseif first == "'" then
    local scanned, close_pos = scan_single_quoted(line, pos)
    if not scanned then
      return nil
    end
    key = scanned
    pos = close_pos + 1
  else
    local colon_pos = line:find(':', pos, true)
    if not colon_pos then
      return nil
    end
    key = line:sub(pos, colon_pos - 1)
    pos = colon_pos
  end

  -- Require `:` followed by end-of-line, whitespace, or another character (inline value).
  if line:sub(pos, pos) ~= ':' then
    return nil
  end
  local after = line:sub(pos + 1, pos + 1)
  if after ~= '' and after ~= ' ' and after ~= '\t' then
    return nil
  end

  return key
end

--- Strip a trailing ` # comment` from an anchor line so `scripts: # foo` is
--- treated the same as `scripts:`. Safe for anchor lines because they do not
--- contain string literals where `#` would be a valid character.
--- @param line string
--- @return string
--- @private
local function strip_trailing_comment(line)
  return (line:gsub('%s+#.*$', ''))
end

--- Find line number of a script key in config file.
--- Supports v6 (top-level scripts:) and v7 (melos: > scripts: nesting),
--- both bare and quoted YAML keys (e.g. `"build:apk"`), and anchor lines with
--- trailing `# comment` such as `melos: # section`.
---
--- @param desc table config descriptor
--- @param script_key string
--- @return number line number, 0 if not found
--- @private
local function find_script_line_number(desc, script_key)
  local file = io.open(desc.path, 'r')
  if not file then
    return 0
  end

  local state = 'BEFORE_ANCHOR'
  local scripts_indent = nil
  -- Indent of direct children of scripts: (determined on first child line seen).
  -- Only lines at exactly this indent are candidate script keys.
  local script_key_indent = nil
  local line_num = 0
  local found = 0

  for raw in file:lines() do
    line_num = line_num + 1
    local line = raw:gsub('\r$', '')
    local indent = line_indent(line)
    local is_blank = line:match('^%s*$') ~= nil
    local is_comment = line:match('^%s*#') ~= nil

    if not is_blank and not is_comment then
      if state == 'BEFORE_ANCHOR' then
        local bare = strip_trailing_comment(line)
        if desc.flavor == 'v6' then
          if bare:match('^scripts:%s*$') then
            state = 'IN_SCRIPTS'
            scripts_indent = 0
          end
        else
          if bare:match('^melos:%s*$') then
            state = 'ANCHOR_FOUND'
          end
        end
      elseif state == 'ANCHOR_FOUND' then
        if indent == 0 then
          break
        end -- left melos: section
        local bare = strip_trailing_comment(line)
        if bare:match('^%s+scripts:%s*$') then
          state = 'IN_SCRIPTS'
          scripts_indent = indent
        end
      elseif state == 'IN_SCRIPTS' then
        if indent <= scripts_indent then
          break
        end
        -- Determine the expected indent for direct script keys on the first child line.
        if script_key_indent == nil then
          script_key_indent = indent
        end
        -- Only match at the direct-child indent level to avoid false hits in sub-fields.
        if indent == script_key_indent then
          local key = extract_mapping_key(line, indent)
          if key == script_key then
            found = line_num
            break
          end
        end
      end
    end
  end

  file:close()
  return found
end

--- Parse config file and return all script objects.
--- @return table list of script objects (sorted by name)
--- @private
local function parse_melos_yaml()
  local desc = get_config_descriptor()
  if not desc then
    return {}
  end

  local defs = get_script_definitions_from_yq(desc)
  if not defs then
    return {}
  end

  if vim.tbl_isempty(defs) then
    vim.notify('melos.nvim: no scripts found in ' .. desc.path, vim.log.levels.INFO)
    return {}
  end

  local result = {}
  local group_keys = {}

  for key, value in pairs(defs) do
    local entry = normalize_script(key, value, group_keys)
    if entry then
      entry.line = find_script_line_number(desc, key)
      table.insert(result, entry)
    end
  end

  if #group_keys > 0 then
    vim.notify(
      'melos.nvim: '
        .. #group_keys
        .. ' script group(s) skipped (not yet supported): '
        .. table.concat(group_keys, ', '),
      vim.log.levels.WARN
    )
  end

  table.sort(result, function(a, b)
    return a.name < b.name
  end)

  return result
end

--- Get all available Melos scripts from the current project's config file.
---
--- Returns a list of script objects sorted by name, usable by the picker module.
--- Script groups (v7.3+ nested scripts:) are excluded; a warning is shown when any are skipped.
---
--- Each object has the following fields:
--- - `name` (string): script key
--- - `description` (string): description or generated fallback
--- - `command` (string): same as name (used as `melos run <command>`)
--- - `id` (string): same as name (backward compat)
--- - `line` (number): line number in config file, 0 if not found
--- - `kind` ('run'|'steps'|'exec'|'string'|'unknown'): script form
---
--- @return table list of script objects
M.get_scripts = function()
  return parse_melos_yaml()
end

return M
