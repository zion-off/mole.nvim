local M = {}

M.config = nil

function M.setup(opts)
  M.config = require("mole.config").apply(opts)

  M._register_keymaps()
  M._register_commands()
  M._register_which_key()

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("MoleCleanup", { clear = true }),
    callback = function()
      local session = require("mole.session")
      if session.state.active then
        session.stop(M.config)
      end
    end,
  })
end

function M._register_keymaps()
  local keys = M.config.keys

  vim.keymap.set("n", keys.start_session, function()
    M.start_session()
  end, { desc = "Mole: Start session" })

  vim.keymap.set("n", keys.stop_session, function()
    M.stop_session()
  end, { desc = "Mole: Stop session" })

  vim.keymap.set("n", keys.resume_session, function()
    M.resume_session()
  end, { desc = "Mole: Resume session" })

  vim.keymap.set("n", keys.toggle_window, function()
    M.toggle_window()
  end, { desc = "Mole: Toggle window" })

  vim.keymap.set("v", keys.annotate, function()
    M.annotate()
  end, { desc = "Mole: Add annotation" })
end

function M._register_commands()
  vim.api.nvim_create_user_command("MoleStart", function()
    M.start_session()
  end, { desc = "Start mole session" })

  vim.api.nvim_create_user_command("MoleStop", function()
    M.stop_session()
  end, { desc = "Stop mole session" })

  vim.api.nvim_create_user_command("MoleResume", function()
    M.resume_session()
  end, { desc = "Resume a previous mole session" })

  vim.api.nvim_create_user_command("MoleToggle", function()
    M.toggle_window()
  end, { desc = "Toggle annotation window" })
end

function M._register_which_key()
  local ok, wk = pcall(require, "which-key")
  if ok then
    wk.add({
      { "<leader>m", group = "mole" },
    })
  end
end

function M.start_session()
  require("mole.session").start(M.config)
end

function M.stop_session()
  require("mole.session").stop(M.config)
end

function M.resume_session()
  require("mole.picker").pick_session(M.config, function(file_path)
    require("mole.session").resume(M.config, file_path)
  end)
end

function M.toggle_window()
  local session = require("mole.session")
  if not session.state.active then
    vim.notify("No active mole session", vim.log.levels.WARN)
    return
  end
  require("mole.window").toggle(M.config, session.state.bufnr)
end

function M.annotate()
  local session = require("mole.session")
  if not session.state.active then
    vim.notify("No active mole session. Start one first.", vim.log.levels.WARN)
    return
  end

  local selection = M._capture_selection()

  require("mole.input").show(M.config, M.config.capture_mode, selection, function(note, mode)
    if note ~= nil then
      -- If mode was toggled to "snippet" but we didn't capture text yet, grab it now
      if mode == "snippet" and not selection.text then
        selection.text = M._get_visual_text(
          selection.bufnr,
          selection.start_line,
          selection.start_col,
          selection.end_line,
          selection.end_col,
          selection.visual_mode
        )
      end
      require("mole.writer").append(session.state, mode, selection, note)
    end
  end)
end

function M._get_visual_text(bufnr, start_line, start_col, end_line, end_col, visual_mode)
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  if #lines == 0 then
    return ""
  end

  -- Linewise visual mode: return full lines, no column slicing
  if visual_mode == "V" then
    return table.concat(lines, "\n")
  end

  -- Characterwise visual mode: slice columns
  if #lines == 1 then
    return lines[1]:sub(start_col + 1, end_col + 1)
  end
  lines[1] = lines[1]:sub(start_col + 1)
  lines[#lines] = lines[#lines]:sub(1, end_col + 1)
  return table.concat(lines, "\n")
end

function M._capture_selection()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)

  local bufnr = vim.api.nvim_get_current_buf()
  local visual_mode = vim.fn.visualmode()

  local start_pos = vim.api.nvim_buf_get_mark(bufnr, "<")
  local end_pos = vim.api.nvim_buf_get_mark(bufnr, ">")
  local start_line = start_pos[1]
  local start_col = start_pos[2]
  local end_line = end_pos[1]
  local end_col = end_pos[2]

  local file = vim.api.nvim_buf_get_name(bufnr)
  local relative_file = vim.fn.fnamemodify(file, ":~:.")

  local result = {
    file = relative_file,
    start_line = start_line,
    start_col = start_col,
    end_line = end_line,
    end_col = end_col,
    filetype = vim.bo[bufnr].filetype,
    bufnr = bufnr,
    visual_mode = visual_mode,
  }

  -- Pre-capture text if default mode is "snippet"
  if M.config.capture_mode == "snippet" then
    result.text = M._get_visual_text(bufnr, start_line, start_col, end_line, end_col, visual_mode)
  end

  return result
end

return M
