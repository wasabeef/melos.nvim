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
    local description = ""

    -- value がテーブルで description プロパティを持っていればそれを採用
    if type(value) == "table" and value.description and type(value.description) == "string" then
      description = value.description
    end
    -- 他の形式の value (文字列や run/exec を持つテーブルなど) であっても、
    -- key (script_name) が存在する限り、それは melos run <key> で実行可能なスクリプトとみなす。
    -- description がなければ空文字のまま。

    table.insert(parsed_scripts, {
      name = script_name,
      description = description,
      command = key, -- picker は id を使うので、この command は補助的なもの
      id = key      -- melos run <id> で実行するため
    })
  end

  -- スクリプト名でソート (アルファベット昇順)
  table.sort(parsed_scripts, function(a, b)
    return a.name < b.name
  end)

  return parsed_scripts
end

M.get_scripts = function()
  return parse_melos_yaml()
end

return M
