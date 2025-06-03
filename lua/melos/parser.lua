local vim = _G.vim -- Explicitly use the global vim object
local M = {}

--[[-
Check if melos.yaml exists in the current directory.
@return string|nil Path to melos.yaml if found, otherwise nil.
--]]
local function get_melos_yaml_path()
  local path = vim.fn.getcwd() .. "/melos.yaml"
  local file = io.open(path, "r")
  if file then
    file:close()
    return path
  else
    vim.notify("melos.yaml not found in the current directory.", vim.log.levels.ERROR)
    return nil
  end
end

--[[-
Get script definitions (name and description) from melos.yaml using yq.
@param melos_yaml_path string Path to melos.yaml.
@return table|nil Table of script definitions if successful, otherwise nil.
--]]
local function get_script_definitions_from_yq(melos_yaml_path)
  local yq_command = string.format("yq e '.scripts' -o=json %s", vim.fn.shellescape(melos_yaml_path))
  local json_output = vim.fn.system(yq_command)

  if vim.v.shell_error ~= 0 then
    vim.notify(
      "Failed to parse melos.yaml with yq. Make sure yq is installed and melos.yaml is valid.\nError: " .. json_output,
      vim.log.levels.ERROR
    )
    return nil
  end

  local ok, scripts_json = pcall(vim.fn.json_decode, json_output)
  if not ok or type(scripts_json) ~= "table" then
    vim.notify("Failed to decode JSON output from yq for scripts section. Output: " .. json_output, vim.log.levels.ERROR)
    return nil
  end
  return scripts_json
end

--[[-
Find the line number of a specific script key in melos.yaml.
@param melos_yaml_path string Path to melos.yaml.
@param script_key string The script key to search for (e.g., "build_runner").
@return number The line number if found, otherwise 0.
--]]
local function find_script_line_number(melos_yaml_path, script_key)
  local line_number = 0
  local file = io.open(melos_yaml_path, "r")
  if not file then
    vim.notify("Could not open " .. melos_yaml_path .. " to determine line number for: " .. script_key, vim.log.levels.WARN)
    return 0
  end

  local current_line_num = 0
  local in_scripts_section = false
  -- Regex to match the script key, ensuring it's a key (ends with :),
  -- followed by optional whitespace, and then the end of the line.
  -- This pattern does NOT match if there is a comment on the same line after the key.
  -- Example for key "test": "^%s*test:%s*$"
  local escaped_key_part = vim.fn.escape(script_key, ".*[^$") -- Escape regex special chars in the key
  local key_pattern = "^%s*" .. escaped_key_part .. ":%s*$"

  for line_content in file:lines() do
    current_line_num = current_line_num + 1
    line_content = line_content:gsub('\r$', '') -- Strip trailing CR if present

    if not in_scripts_section then
      if line_content:match("^scripts:") then
        in_scripts_section = true
      end
    else -- Inside "scripts:" section
      if line_content:match(key_pattern) then
        line_number = current_line_num
        break
      end
      -- If a non-indented, non-comment, non-empty line is found that is not "scripts:",
      -- assume it's the end of the scripts section or a new top-level key.
      if not line_content:match("^%s%s*") and
         not line_content:match("^%s*#") and
         not line_content:match("^%s*$") and
         not line_content:match("^scripts:") then
        break
      end
    end
  end
  file:close()
  return line_number
end

--[[-
Parse melos.yaml to extract script information including name, description, and line number.
@return table A sorted list of script objects.
--]]
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
    local description = ""

    if type(value) == "table" and value.description and type(value.description) == "string" then
      description = value.description
    elseif type(value) == "string" then
      -- If the value is a simple string (the command itself), there's no separate description.
      description = "" 
    end

    local line_number = find_script_line_number(melos_yaml_path, key)

    table.insert(parsed_scripts, {
      name = script_name,
      description = description,
      command = key, -- Used as the script ID for `melos run <id>`
      id = key,      -- Retained for compatibility, same as command
      line = line_number,
    })
  end

  table.sort(parsed_scripts, function(a, b)
    return a.name < b.name
  end)

  return parsed_scripts
end

M.get_scripts = function()
  return parse_melos_yaml()
end

return M
