--- @module melos.parser
--- YAML parsing module for melos.nvim plugin
---
--- This module handles parsing of melos.yaml files to extract script definitions
--- and their metadata. It uses the 'yq' command-line tool for reliable YAML parsing.
---
--- @author Daichi Furiya
--- @copyright 2024
--- @license MIT

local M = {}

--- Check if melos.yaml exists in the current working directory
---
--- @return string|nil Path to melos.yaml if found, nil otherwise
--- @private
local function get_melos_yaml_path()
  local path = vim.fn.getcwd() .. '/melos.yaml'
  local file = io.open(path, 'r')
  if file then
    file:close()
    return path
  else
    vim.notify('melos.yaml not found in the current directory.', vim.log.levels.ERROR)
    return nil
  end
end

--- Extract script definitions from melos.yaml using yq command-line tool
---
--- This function uses 'yq' to parse the YAML file and extract the scripts section
--- as JSON, which is then decoded into a Lua table for further processing.
---
--- @param melos_yaml_path string Path to the melos.yaml file
--- @return table|nil Table of script definitions if successful, nil on error
--- @private
local function get_script_definitions_from_yq(melos_yaml_path)
  local yq_command = string.format("yq e '.scripts' -o=json %s", vim.fn.shellescape(melos_yaml_path))
  local json_output = vim.fn.system(yq_command)

  if vim.v.shell_error ~= 0 then
    vim.notify(
      'Failed to parse melos.yaml with yq. Make sure yq is installed and melos.yaml is valid.\nError: ' .. json_output,
      vim.log.levels.ERROR
    )
    return nil
  end

  local ok, scripts_json = pcall(vim.fn.json_decode, json_output)
  if not ok or type(scripts_json) ~= 'table' then
    vim.notify(
      'Failed to decode JSON output from yq for scripts section. Output: ' .. json_output,
      vim.log.levels.ERROR
    )
    return nil
  end
  return scripts_json
end

--- Find the line number where a specific script is defined in melos.yaml
---
--- This function searches through the melos.yaml file to find the exact line
--- where a script is defined, enabling the edit functionality to jump directly
--- to the script definition.
---
--- @param melos_yaml_path string Path to the melos.yaml file
--- @param script_key string The script key/name to search for (e.g., "build_runner")
--- @return number Line number where the script is defined, 0 if not found
--- @private
local function find_script_line_number(melos_yaml_path, script_key)
  local line_number = 0
  local file = io.open(melos_yaml_path, 'r')
  if not file then
    vim.notify(
      'Could not open ' .. melos_yaml_path .. ' to determine line number for: ' .. script_key,
      vim.log.levels.WARN
    )
    return 0
  end

  local current_line_num = 0
  local in_scripts_section = false
  -- Regex to match the script key, ensuring it's a key (ends with :),
  -- followed by optional whitespace, and then the end of the line.
  -- This pattern does NOT match if there is a comment on the same line after the key.
  -- Example for key "test": "^%s*test:%s*$"
  local escaped_key_part = vim.fn.escape(script_key, '.*[^$') -- Escape regex special chars in the key
  local key_pattern = '^%s*' .. escaped_key_part .. ':%s*$'

  for line_content in file:lines() do
    current_line_num = current_line_num + 1
    line_content = line_content:gsub('\r$', '') -- Strip trailing CR if present

    if not in_scripts_section then
      if line_content:match('^scripts:') then
        in_scripts_section = true
      end
    else -- Inside "scripts:" section
      if line_content:match(key_pattern) then
        line_number = current_line_num
        break
      end
      -- If a non-indented, non-comment, non-empty line is found that is not "scripts:",
      -- assume it's the end of the scripts section or a new top-level key.
      if
        not line_content:match('^%s%s*')
        and not line_content:match('^%s*#')
        and not line_content:match('^%s*$')
        and not line_content:match('^scripts:')
      then
        break
      end
    end
  end
  file:close()
  return line_number
end

--- Parse melos.yaml to extract all script information
---
--- This function orchestrates the entire parsing process by:
--- 1. Locating the melos.yaml file
--- 2. Extracting script definitions using yq
--- 3. Finding line numbers for each script
--- 4. Sorting scripts alphabetically by name
---
--- @return table A sorted list of script objects with name, description, command, and line info
--- @private
local function parse_melos_yaml()
  local melos_yaml_path = get_melos_yaml_path()
  if not melos_yaml_path then
    return {}
  end

  local script_definitions = get_script_definitions_from_yq(melos_yaml_path)
  if not script_definitions then
    return {}
  end

  local parsed_scripts = {}
  for key, value in pairs(script_definitions) do
    local script_name = key
    local description = ''

    if type(value) == 'table' and value.description and type(value.description) == 'string' then
      description = value.description
    elseif type(value) == 'string' then
      -- If the value is a simple string (the command itself), there's no separate description.
      description = ''
    end

    local line_number = find_script_line_number(melos_yaml_path, key)

    table.insert(parsed_scripts, {
      name = script_name,
      description = description,
      command = key, -- Used as the script ID for `melos run <id>`
      id = key, -- Retained for compatibility, same as command
      line = line_number,
    })
  end

  table.sort(parsed_scripts, function(a, b)
    return a.name < b.name
  end)

  return parsed_scripts
end

--- Get all available Melos scripts from the current project's melos.yaml
---
--- This is the main public interface for retrieving script information.
--- It returns a list of script objects that can be used by the picker module
--- to display scripts in the Telescope interface.
---
--- @return table List of script objects, each containing:
---   - name: string - The script name/key
---   - description: string - Optional description from melos.yaml
---   - command: string - Command identifier for melos run
---   - id: string - Alias for command (for compatibility)
---   - line: number - Line number in melos.yaml where script is defined (0 if not found)
---
--- @usage
--- local scripts = require("melos.parser").get_scripts()
--- for _, script in ipairs(scripts) do
---   print(script.name, script.description)
--- end
M.get_scripts = function()
  return parse_melos_yaml()
end

return M
