local vim = _G.vim -- Explicitly use the global vim object
local M = {}

local function parse_melos_yaml()
  local melos_yaml_path = vim.fn.getcwd() .. "/melos.yaml"
  
  -- Check if melos.yaml exists
  local file_check = io.open(melos_yaml_path, "r")
  if not file_check then
    vim.notify("melos.yaml not found in the current directory.", vim.log.levels.ERROR)
    return {}
  end
  file_check:close()

  -- Get script definitions using yq
  local yq_command = string.format("yq e '.scripts' -o=json %s", vim.fn.shellescape(melos_yaml_path))
  local json_output = vim.fn.system(yq_command)

  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to parse melos.yaml with yq. Make sure yq is installed and melos.yaml is valid.\nError: " .. json_output, vim.log.levels.ERROR)
    return {}
  end

  local ok, scripts_json = pcall(vim.fn.json_decode, json_output)
  if not ok or type(scripts_json) ~= "table" then
    vim.notify("Failed to decode JSON output from yq for scripts section. Output: " .. json_output, vim.log.levels.ERROR)
    return {}
  end

  local parsed_scripts = {}
  for key, value in pairs(scripts_json) do
    local script_name = key
    local line_number = 0
    local description = ""

    if type(value) == "table" and value.description and type(value.description) == "string" then
      description = value.description
    elseif type(value) == "string" then
      -- If the value is a simple string, it's the command itself, no separate description
      description = "" 
    end

    -- Get line number by reading melos.yaml directly
    local melos_file_for_lines = io.open(melos_yaml_path, "r")
    if melos_file_for_lines then
      local current_line = 0
      local in_scripts_section = false
      -- Regex to match the script key, ensuring it's a key (ends with :),
      -- followed by optional whitespace and an optional comment, then end of line.
      local escaped_key_part = vim.fn.escape(key, ".*[^$")
      local key_pattern = "^%s*" .. escaped_key_part .. ":%s*$"

      for line_content in melos_file_for_lines:lines() do
        current_line = current_line + 1
        line_content = line_content:gsub('\r$', '') -- Strip trailing CR if present

        if not in_scripts_section then
          if line_content:match("^scripts:") then -- Detect start of "scripts:" section
            in_scripts_section = true
          end
        else -- Inside "scripts:" section
          if line_content:match(key_pattern) then
            line_number = current_line
            break -- Exit loop if found
          end
          -- If we encounter a line that is not indented, it might signify the end of the scripts section.
          -- This check is basic and relies on yq having given us a valid script key that *should* be found.
          if not line_content:match("^%s%s*") and -- not indented (allows empty lines with %s*)
             not line_content:match("^%s*#") and -- not a comment
             not line_content:match("^%s*$") and -- not an empty line
             not line_content:match("^scripts:") then -- not the scripts: line itself
             -- If we are in scripts_section and hit a new top-level key, break.
             -- This helps prevent searching the entire file if something is wrong.
            break 
          end
        end
      end
      melos_file_for_lines:close()
    else
      vim.notify("Could not re-open " .. melos_yaml_path .. " to determine line numbers.", vim.log.levels.ERROR)
    end

    table.insert(parsed_scripts, {
      name = script_name,
      description = description,
      command = key, -- For picker/execution reference
      id = key,      -- For execution with melos run <id>
      line = line_number 
    })
  end

  -- Sort by script name (alphabetical ascending)
  table.sort(parsed_scripts, function(a, b)
    return a.name < b.name
  end)

  return parsed_scripts
end

M.get_scripts = function()
  return parse_melos_yaml()
end

return M
