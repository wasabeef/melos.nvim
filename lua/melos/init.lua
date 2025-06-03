local picker = require("melos.picker") -- Changed from melos_nvim.picker
local config = require("melos.config") -- Changed from melos_nvim.config

local M = {}

-- ユーザーが設定を渡すための setup 関数
function M.setup(user_options)
  config.setup(user_options)
end

-- メインの実行関数
function M.run()
  picker.show_scripts()
end

return M
