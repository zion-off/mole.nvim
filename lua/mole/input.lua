local Input = require("nui.input")

local M = {}

local PROMPT = " > "

---Open a full-screen floating scratch buffer for multiline note editing.
---@param config table Plugin config
---@param initial_text string Text pre-filled into the buffer
---@param initial_mode string "location" or "snippet"
---@param callback fun(note: string|nil, mode: string)
local function open_expanded(config, initial_text, initial_mode, callback)
  local mode = initial_mode

  local function title()
    return " mole [" .. mode .. "] "
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "markdown"

  if initial_text ~= "" then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(initial_text, "\n"))
  end

  local input_conf = config.input
  local width = math.max(input_conf.width, 60)
  local height = 12
  local ui = vim.api.nvim_list_uis()[1]
  local total_w = ui and ui.width or vim.o.columns
  local total_h = ui and ui.height or vim.o.lines
  local col = math.floor((total_w - width) / 2)
  local row = math.floor((total_h - height) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = col,
    row = row,
    style = "minimal",
    border = input_conf.border,
    title = title(),
    title_pos = "right",
    footer = " <C-CR>/<leader><CR> save  <Esc>/q cancel  <Tab> mode ",
    footer_pos = "left",
  })

  vim.wo[win].wrap = true
  vim.cmd("startinsert!")

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end

  local function confirm()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    -- Strip trailing blank lines
    while #lines > 0 and lines[#lines] == "" do
      table.remove(lines)
    end
    local text = table.concat(lines, "\n")
    close()
    -- Treat an empty expanded buffer the same as cancellation
    callback(text ~= "" and text or nil, mode)
  end

  local function cancel()
    close()
    callback(nil, mode)
  end

  local map_opts = { noremap = true, buffer = buf, silent = true }

  vim.keymap.set({ "i", "n" }, "<Tab>", function()
    mode = mode == "location" and "snippet" or "location"
    vim.api.nvim_win_set_config(win, { title = title(), title_pos = "right" })
  end, map_opts)

  vim.keymap.set({ "i", "n" }, "<C-CR>", confirm, map_opts)
  vim.keymap.set({ "i", "n" }, "<leader><CR>", confirm, map_opts)
  vim.keymap.set("n", "<Esc>", cancel, map_opts)
  vim.keymap.set("n", "q", cancel, map_opts)
end

---Show the inline nui input popup.
---@param config table Plugin config
---@param default_mode string "location" or "snippet"
---@param selection table { start_line, end_line, ... }
---@param callback fun(note: string|nil, mode: string)
function M.show(config, default_mode, selection, callback)
  local mode = default_mode
  local input_conf = config.input

  local function mode_label()
    return " mole [" .. mode .. "] "
  end

  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local offset = selection.end_line - cursor_line + 2

  -- Flag to suppress on_close when expanding to multiline
  local expanding = false

  local input = Input({
    relative = "cursor",
    position = { row = offset, col = 0 },
    size = { width = input_conf.width },
    border = {
      style = input_conf.border,
      text = { top = mode_label(), top_align = "right" },
    },
    win_options = {
      winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
    },
  }, {
    prompt = PROMPT,
    on_submit = function(value)
      callback(value, mode)
    end,
    on_close = function()
      if not expanding then
        callback(nil, mode)
      end
    end,
  })

  input:map("i", "<Tab>", function()
    mode = mode == "location" and "snippet" or "location"
    input.border:set_text("top", mode_label(), "right")
  end, { noremap = true })

  input:map("i", "<Esc>", function()
    input:unmount()
  end, { noremap = true })

  input:map("n", "<Esc>", function()
    input:unmount()
  end, { noremap = true })

  local expand_key = input_conf.expand_key or "<C-e>"
  input:map("i", expand_key, function()
    -- Extract current typed text by stripping the prompt prefix
    local line = vim.api.nvim_buf_get_lines(input.bufnr, 0, 1, false)[1] or ""
    local current_text = line:sub(#PROMPT + 1)
    local current_mode = mode

    -- nui calls on_close synchronously inside unmount(); the flag suppresses
    -- callback(nil) during the transition to the expanded buffer.
    expanding = true
    input:unmount()
    expanding = false

    open_expanded(config, current_text, current_mode, callback)
  end, { noremap = true })

  input:mount()
end

return M
