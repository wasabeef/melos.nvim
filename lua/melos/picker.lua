--- @module melos.picker
--- Telescope picker module for melos.nvim plugin
---
--- This module provides the Telescope integration for displaying and selecting
--- Melos scripts. It handles both running scripts and editing their definitions.
---
--- @author Daichi Furiya
--- @copyright 2025
--- @license MIT

local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local conf = require('telescope.config').values
local action_state = require('telescope.actions.state')
local actions = require('telescope.actions')

local config = require('melos.config')
local parser = require('melos.parser')

local M = {}

--- Helper function to auto-scroll terminal window to show latest output
---
--- This function ensures that when output is written to the terminal buffer,
--- the window automatically scrolls to show the latest content at the bottom.
--- Only works when the terminal window is currently focused.
---
--- @param win number The window ID of the terminal
--- @param buf number The buffer number of the terminal
--- @private
local function scroll_pty_terminal(win, buf)
  if not (vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  if vim.api.nvim_get_current_win() == win and vim.api.nvim_win_get_buf(win) == buf then
    local target_line = vim.api.nvim_buf_line_count(buf)
    vim.api.nvim_win_set_cursor(win, { target_line, 0 })
    vim.api.nvim_win_call(win, function()
      vim.cmd('normal! zb') -- Bring the current line to the bottom
    end)
    vim.cmd('redraw!')
  end
end

--[[-
Helper function to scroll the terminal window when pty is false (non-interactive).
Adjusts scrolloff to keep the last line visible, avoiding mode-dependent commands.
@param win table The window ID of the terminal.
@param buf number The buffer number of the terminal.
--]]
local function scroll_non_pty_terminal(win, buf)
  if not (vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(buf)) then
    return
  end

  if vim.api.nvim_get_current_win() == win then
    local current_mode = vim.fn.mode(true)
    if current_mode ~= 'i' and current_mode ~= 'R' then -- Only scroll if not in insert/replace mode
      local target_line = vim.api.nvim_buf_line_count(buf)
      local original_scrolloff = vim.api.nvim_get_option_value('scrolloff', { win = win })

      vim.api.nvim_set_option_value('scrolloff', 999, { win = win }) -- Ensure cursor line is visible
      vim.api.nvim_win_set_cursor(win, { target_line, 0 })
      vim.api.nvim_set_option_value('scrolloff', original_scrolloff, { win = win }) -- Restore scrolloff
      -- No explicit redraw command to avoid mode errors with pty=false
    end
  end
end

--[[-
Shows a Telescope picker for Melos scripts.
Allows running a script or jumping to its definition in melos.yaml.
@param opts table Options for the picker.
  @field action_type string ("run"|"edit") Defines the action on selection.
                           "run" executes the script.
                           "edit" opens melos.yaml at the script's line.
--]]
function M.show_scripts(opts)
  opts = opts or {}

  local scripts = parser.get_scripts()
  if not scripts or #scripts == 0 then
    vim.notify('No melos scripts found or failed to parse melos.yaml.', vim.log.levels.INFO)
    return
  end

  pickers
    .new(opts, {
      prompt_title = 'Melos Scripts',
      finder = finders.new_table({
        results = scripts,
        entry_maker = function(entry)
          local name_display_width = 30 -- Display width for script name (adjust as needed)
          local display_name = entry.name

          -- Truncate script name if it exceeds display width (e.g., append ...).
          if #display_name > name_display_width then
            display_name = string.sub(display_name, 1, name_display_width - 3) .. '...'
          else
            -- Pad with spaces if shorter
            display_name = display_name .. string.rep(' ', name_display_width - #display_name)
          end

          local display_text
          if entry.description and entry.description ~= '' then
            display_text = string.format('%s | %s', display_name, entry.description)
          else
            display_text = display_name -- Only padded script name if no description
          end

          return {
            value = entry,
            display = display_text,
            ordinal = entry.name, -- Sorting and filtering are done by the original script name
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()

          if opts.action_type == 'edit' then
            if selection and selection.value and selection.value.name and selection.value.line then
              if selection.value.line > 0 then
                local melos_yaml_path = vim.fn.getcwd() .. '/melos.yaml'
                -- Check if melos.yaml exists before trying to open it
                local f = io.open(melos_yaml_path, 'r')
                if f then
                  f:close()
                  vim.cmd('edit ' .. vim.fn.fnameescape(melos_yaml_path))
                  vim.api.nvim_win_set_cursor(0, { selection.value.line, 0 })
                  vim.notify('Opened melos.yaml and jumped to script: ' .. selection.value.name, vim.log.levels.INFO)
                else
                  vim.notify('melos.yaml not found.', vim.log.levels.ERROR)
                end
              else
                vim.notify(
                  'Could not determine line number for script: '
                    .. selection.value.name
                    .. '. Opening melos.yaml at the beginning.',
                  vim.log.levels.WARN
                )
                local melos_yaml_path = vim.fn.getcwd() .. '/melos.yaml'
                local f = io.open(melos_yaml_path, 'r')
                if f then
                  f:close()
                  vim.cmd('edit ' .. vim.fn.fnameescape(melos_yaml_path))
                else
                  vim.notify('melos.yaml not found.', vim.log.levels.ERROR)
                end
              end
            else
              vim.notify('No script selected or script data (name/line) missing.', vim.log.levels.WARN)
            end
          else -- Default to "run" action (or if action_type is not 'edit')
            if selection and selection.value and selection.value.id then
              local command_to_run = string.format('melos run %s', selection.value.id)
              vim.notify(string.format('Running: %s', command_to_run), vim.log.levels.INFO)

              local term_width = config.options.terminal_width
              local term_height = config.options.terminal_height

              -- Calculation to center the floating window on the screen
              local screen_width = vim.api.nvim_get_option_value('columns', {})
              local screen_height = vim.api.nvim_get_option_value('lines', {})
              local win_col = math.floor((screen_width - term_width) / 2)
              local win_row = math.floor((screen_height - term_height) / 2)

              -- Create a buffer for the floating window (unlisted, scratch buffer)
              local buf = vim.api.nvim_create_buf(false, true)

              -- Open the floating window
              local win = vim.api.nvim_open_win(buf, true, {
                relative = 'editor',
                width = term_width,
                height = term_height,
                col = win_col,
                row = win_row,
                style = 'minimal',
                border = 'single', -- or "rounded", "double", "none"
              })

              -- Set window title (optional)
              vim.api.nvim_win_set_option(win, 'winhl', 'Normal:FloatingWindow') -- To customize background color, etc.
              vim.api.nvim_buf_set_name(buf, 'Melos: ' .. selection.value.name)

              -- Open terminal in the floating window's buffer
              local term_opts = { term_name = 'Melos Run', pty = false } -- pty is hardcoded to false
              vim.fn.termopen(command_to_run, term_opts)

              -- Focus the window to easily switch to terminal mode
              vim.api.nvim_set_current_win(win)

              -- Listen for line changes in the terminal buffer to handle scrolling
              if term_opts.pty == nil or term_opts.pty == true then -- This condition is currently always false
                vim.api.nvim_buf_attach(buf, false, {
                  on_lines = function(_, current_bufnr, _, _, _, _, _, _, _) -- Unused vars
                    if current_bufnr ~= buf then
                      return
                    end
                    vim.schedule(function()
                      scroll_pty_terminal(win, buf)
                    end)
                  end,
                })
              else -- pty is false, this block is executed
                vim.api.nvim_buf_attach(buf, false, {
                  on_lines = function(_, current_bufnr, _, _, _, _, _, _, _) -- Unused vars
                    if current_bufnr ~= buf then
                      return
                    end
                    vim.schedule(function()
                      scroll_non_pty_terminal(win, buf)
                    end)
                  end,
                })
              end
            else
              vim.notify('No script selected or script ID missing.', vim.log.levels.WARN)
            end
          end
        end)
        return true
      end,
    })
    :find()
end

return M
