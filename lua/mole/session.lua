local M = {}

M.state = {
  active = false,
  file_path = nil,
  bufnr = nil,
}

local function notify(config, msg, level)
  if config.notify then
    vim.notify(msg, level)
  end
end

function M.start(config)
  if M.state.active then
    notify(config, "Mole session already active", vim.log.levels.WARN)
    return
  end

  vim.fn.mkdir(config.session_dir, "p")

  local name = config.session_name
  if type(name) == "function" then
    name = name()
  end
  local is_default_name = not name or name == ""
  if is_default_name then
    name = "session_" .. os.date("%Y-%m-%d_%H-%M-%S")
  end

  local filename = name .. ".md"
  local file_path = config.session_dir .. "/" .. filename

  if vim.fn.filereadable(file_path) == 1 then
    return M.resume(config, file_path)
  end

  local cwd = vim.fn.getcwd()

  local title = is_default_name and ("Session — " .. os.date("%b %d, %Y %I:%M %p")) or name

  local header = config.format.header({
    title = title,
    file_path = file_path,
    cwd = cwd,
    timestamp = os.date("%Y-%m-%d %H:%M:%S"),
  })

  local f = io.open(file_path, "w")
  if not f then
    vim.notify("Failed to create session file: " .. file_path, vim.log.levels.ERROR)
    return
  end
  f:write(table.concat(header, "\n"))
  f:close()

  local bufnr = vim.fn.bufadd(file_path)
  vim.fn.bufload(bufnr)
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].filetype = "markdown"

  M.state = {
    active = true,
    file_path = file_path,
    bufnr = bufnr,
  }

  if config.auto_open_panel then
    require("mole.window").open(config, bufnr)
  end

  local marks = require("mole.marks")
  marks.apply(config, M.state)
  marks.setup_autocmds(config, M.state)

  notify(config, "Mole session started", vim.log.levels.INFO)
end

function M.stop(config)
  if not M.state.active then
    notify(config, "No active mole session", vim.log.levels.WARN)
    return
  end

  require("mole.marks").teardown()

  local window = require("mole.window")
  window.close()

  local bufnr = M.state.bufnr
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    local footer = config.format.footer({
      timestamp = os.date("%Y-%m-%d %H:%M:%S"),
    })
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    vim.api.nvim_buf_set_lines(bufnr, line_count, line_count, false, footer)
    vim.api.nvim_buf_call(bufnr, function()
      vim.cmd("silent write")
    end)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end

  M.state = {
    active = false,
    file_path = nil,
    bufnr = nil,
  }

  notify(config, "Mole session ended", vim.log.levels.INFO)
end

function M.resume(config, file_path)
  if M.state.active then
    notify(config, "Mole session already active", vim.log.levels.WARN)
    return
  end

  if vim.fn.filereadable(file_path) ~= 1 then
    vim.notify("Session file not found: " .. file_path, vim.log.levels.ERROR)
    return
  end

  local bufnr = vim.fn.bufadd(file_path)
  vim.fn.bufload(bufnr)
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].filetype = "markdown"

  local marker = config.format.resumed({
    timestamp = os.date("%Y-%m-%d %H:%M:%S"),
  })
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, line_count, line_count, false, marker)
  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd("silent write")
  end)

  M.state = {
    active = true,
    file_path = file_path,
    bufnr = bufnr,
  }

  if config.auto_open_panel then
    require("mole.window").open(config, bufnr)
  end

  local marks = require("mole.marks")
  marks.apply(config, M.state)
  marks.setup_autocmds(config, M.state)

  notify(config, "Mole session resumed", vim.log.levels.INFO)
end

function M.get_state()
  return M.state
end

return M
