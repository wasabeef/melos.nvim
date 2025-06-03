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
        local name_display_width = 30 -- Display width for script name (adjust as needed)
        local display_name = entry.name

        -- Truncate script name if it exceeds display width (e.g., append ...).
        if #display_name > name_display_width then
          display_name = string.sub(display_name, 1, name_display_width - 3) .. "..."
        else
          -- Pad with spaces if shorter
          display_name = display_name .. string.rep(" ", name_display_width - #display_name)
        end

        local display_text
        if entry.description and entry.description ~= "" then
          display_text = string.format("%s | %s", display_name, entry.description)
        else
          display_text = display_name -- Only padded script name if no description
        end

        return {
          value = entry,
          display = display_text,
          ordinal = entry.name, -- Sorting and filtering are done by the original script name
        }
      end,
    },
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()

        if opts.action_type == "edit" then
          if selection and selection.value and selection.value.name and selection.value.line then
            if selection.value.line > 0 then
              local melos_yaml_path = vim.fn.getcwd() .. "/melos.yaml"
              -- Check if melos.yaml exists before trying to open it
              local f = io.open(melos_yaml_path, "r")
              if f then
                f:close()
                vim.cmd("edit " .. vim.fn.fnameescape(melos_yaml_path))
                vim.api.nvim_win_set_cursor(0, { selection.value.line, 0 })
                vim.notify("Opened melos.yaml and jumped to script: " .. selection.value.name, vim.log.levels.INFO)
              else
                vim.notify("melos.yaml not found.", vim.log.levels.ERROR)
              end
            else
              vim.notify("Could not determine line number for script: " .. selection.value.name .. ". Opening melos.yaml at the beginning.", vim.log.levels.WARN)
              local melos_yaml_path = vim.fn.getcwd() .. "/melos.yaml"
              local f = io.open(melos_yaml_path, "r")
              if f then
                f:close()
                vim.cmd("edit " .. vim.fn.fnameescape(melos_yaml_path))
              else
                vim.notify("melos.yaml not found.", vim.log.levels.ERROR)
              end
            end
          else
            vim.notify("No script selected or script data (name/line) missing.", vim.log.levels.WARN)
          end
        else -- Default to "run" action (or if action_type is not 'edit')
          if selection and selection.value and selection.value.id then
            local command_to_run = string.format("melos run %s", selection.value.id)
            vim.notify(string.format("Running: %s", command_to_run), vim.log.levels.INFO)
            
            local term_width = config.options.terminal_width
            local term_height = config.options.terminal_height

            -- Calculation to center the floating window on the screen
            local screen_width = vim.api.nvim_get_option_value("columns", {})
            local screen_height = vim.api.nvim_get_option_value("lines", {})
            local win_col = math.floor((screen_width - term_width) / 2)
            local win_row = math.floor((screen_height - term_height) / 2)

            -- Create a buffer for the floating window (unlisted, scratch buffer)
            local buf = vim.api.nvim_create_buf(false, true)
            
            -- Open the floating window
            local win = vim.api.nvim_open_win(buf, true, {
              relative = "editor",
              width = term_width,
              height = term_height,
              col = win_col,
              row = win_row,
              style = "minimal",
              border = "single", -- or "rounded", "double", "none"
            })

            -- Set window title (optional)
            vim.api.nvim_win_set_option(win, "winhl", "Normal:FloatingWindow") -- To customize background color, etc.
            vim.api.nvim_buf_set_name(buf, "Melos: " .. selection.value.name)

            -- Open terminal in the floating window's buffer
            vim.fn.termopen(command_to_run, { term_name = "Melos Run" })
            
            -- Focus the window to easily switch to terminal mode
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
        end
      end)
      return true
    end,
  }):find()
end

return M
