local vim = _G.vim -- Explicitly use the global vim object
local M = {}

local function parse_melos_yaml()
  local melos_yaml_path = vim.fn.getcwd() .. "/melos.yaml"
  local file = io.open(melos_yaml_path, "r")
  if not file then
    vim.notify("melos.yaml not found in the current directory.", vim.log.levels.ERROR)
    return {}
  end
  file:close()

  local yq_command = string.format("yq e '.scripts' -o=json %s", vim.fn.shellescape(melos_yaml_path))
  local json_output = vim.fn.system(yq_command)

  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to parse melos.yaml with yq. Make sure yq is installed and melos.yaml is valid.\nError: " .. json_output, vim.log.levels.ERROR)
    return {}
  end

  local ok, scripts_json = pcall(vim.fn.json_decode, json_output)
  if not ok or type(scripts_json) ~= "table" then
    vim.notify("Failed to decode JSON output from yq for scripts section.", vim.log.levels.ERROR)
    return {}
  end

  local parsed_scripts = {}
  for key, value in pairs(scripts_json) do
    local script_name = key
    local line_number = 0 -- Initialize line number
    local description = ""

    -- If value is a table and has a description property, use it
    if type(value) == "table" and value.description and type(value.description) == "string" then
      description = value.description
    end
    -- Even for other forms of value (string, table with run/exec, etc.),
    -- as long as the key (script_name) exists, it is considered a script executable with melos run <key>.
    -- If there's no description, it remains an empty string.

    -- Get line number by reading melos.yaml directly
    local melos_file = io.open(melos_yaml_path, "r")
    if melos_file then
      local current_line = 0
      local in_scripts_section = false
      -- Regex to match the script key, allowing for various indentations and ensuring it's a key (ends with :)
      -- It also handles potential comments after the key.
      local key_pattern = "^%s*" .. vim.fn.escape(key, ".*[^$") .. ":"

      for line_content in melos_file:lines() do
        current_line = current_line + 1
        if not in_scripts_section then
          if line_content:match("^scripts:") then -- Detect start of "scripts:" section
            in_scripts_section = true
          end
        else -- Inside "scripts:" section
          if line_content:match(key_pattern) then
            line_number = current_line
            break -- Exit loop if found
          end
          -- If we encounter a line that is not indented, it signifies the end of the scripts section or a new top-level key.
          -- This is a simple heuristic and might need refinement for complex melos.yaml structures.
          if not line_content:match("^%s+") and not line_content:match("^%s*#") and not line_content:match("^%s*$") and not line_content:match("^scripts:") then
            -- vim.notify("Exited scripts section at line: " .. current_line .. " due to: " .. line_content, vim.log.levels.DEBUG)
            break -- Assume end of scripts section if a non-indented, non-comment, non-empty line is found
          end
        end
      end
      melos_file:close()
    else
      vim.notify("Could not open " .. melos_yaml_path .. " to determine line numbers.", vim.log.levels.ERROR)
    end

    table.insert(parsed_scripts, {
      name = script_name,
      description = description,
      command = key, -- picker uses id, so this command is auxiliary
      id = key,      -- For execution with melos run <id>
      line = line_number -- Add line number
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
