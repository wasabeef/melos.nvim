local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local parser = require("melos.parser") -- Changed from melos_nvim.parser
local config = require("melos.config") -- Changed from melos_nvim.config

local M = {}

function M.show_scripts(opts)
  opts = opts or {}

  local scripts = parser.get_scripts()
  if not scripts or #scripts == 0 then
    vim.notify("No melos scripts found or failed to parse melos.yaml.", vim.log.levels.INFO)
    return
  end

  pickers.new(opts, {
    prompt_title = "Melos Scripts",
    finder = finders.new_table {
      results = scripts,
      entry_maker = function(entry)
        local name_display_width = 30 -- スクリプト名の表示幅 (適宜調整してください)
        local display_name = entry.name

        -- スクリプト名が表示幅を超える場合は切り詰める (例: ... を末尾に追加)
        if #display_name > name_display_width then
          display_name = string.sub(display_name, 1, name_display_width - 3) .. "..."
        else
          -- 足りない分をスペースでパディング
          display_name = display_name .. string.rep(" ", name_display_width - #display_name)
        end

        local display_text
        if entry.description and entry.description ~= "" then
          display_text = string.format("%s | %s", display_name, entry.description)
        else
          display_text = display_name -- 説明がなければパディングされたスクリプト名のみ
        end

        return {
          value = entry,
          display = display_text,
          ordinal = entry.name, -- ソートやフィルタリングは元のスクリプト名で行う
        }
      end,
    },
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection and selection.value and selection.value.id then
          local command_to_run = string.format("melos run %s", selection.value.id)
          vim.notify(string.format("Running: %s", command_to_run), vim.log.levels.INFO)
          
          local term_width = config.options.terminal_width
          local term_height = config.options.terminal_height

          -- 画面の中央にフローティングウィンドウを配置するための計算
          local screen_width = vim.api.nvim_get_option_value("columns", {})
          local screen_height = vim.api.nvim_get_option_value("lines", {})
          local win_col = math.floor((screen_width - term_width) / 2)
          local win_row = math.floor((screen_height - term_height) / 2)

          -- フローティングウィンドウ用のバッファを作成 (リストされていない、スクラッチバッファ)
          local buf = vim.api.nvim_create_buf(false, true)
          
          -- フローティングウィンドウを開く
          local win = vim.api.nvim_open_win(buf, true, {
            relative = "editor",
            width = term_width,
            height = term_height,
            col = win_col,
            row = win_row,
            style = "minimal",
            border = "single", -- または "rounded", "double", "none"
          })

          -- ウィンドウのタイトルを設定 (オプション)
          vim.api.nvim_win_set_option(win, "winhl", "Normal:FloatingWindow") -- 背景色などをカスタマイズする場合
          vim.api.nvim_buf_set_name(buf, "Melos: " .. selection.value.name)

          -- ターミナルをフローティングウィンドウのバッファで開く
          vim.fn.termopen(command_to_run, { term_name = "Melos Run" })
          
          -- ターミナルモードに移行しやすくするためにフォーカスをウィンドウに当てる
          vim.api.nvim_set_current_win(win)

          -- Listen for line changes in the terminal buffer to handle scrolling
          vim.api.nvim_buf_attach(buf, false, {
            on_lines = function(_, current_bufnr, _, _, _, new_lastline, _)
              if current_bufnr ~= buf then return end

              vim.schedule(function()
                if not (vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(buf)) then
                  return
                end
                -- Ensure the current window is still the terminal window we are tracking
                if vim.api.nvim_get_current_win() == win and vim.api.nvim_win_get_buf(win) == buf then
                  vim.api.nvim_win_set_cursor(win, {new_lastline, 0})
                  vim.api.nvim_win_call(win, function()
                    vim.cmd('normal! zb') -- Bring the current line (new_lastline) to the bottom
                  end)
                  vim.cmd("redraw!")
                end
              end)
            end,
          })
        else
          vim.notify("No script selected or script ID missing.", vim.log.levels.WARN)
        end
      end)
      return true
    end,
  }):find()
end

return M
