local M = {}

M._ns = vim.api.nvim_create_namespace("mole_marks")
M._annotations = {}

-- Extract file + line range from an annotation line (mirrors window.lua pattern)
local function parse_location(line)
  local file, s, e = line:match("`([^:]+):(%d+)-(%d+)`")
  if file then
    return file, tonumber(s), tonumber(e)
  end
  file, s = line:match("`([^:]+):(%d+)`")
  if file then
    return file, tonumber(s), tonumber(s)
  end
  return nil, nil, nil
end

-- Extract the inline note from " — <text>" on the same line
local function extract_inline_note(line)
  return line:match(" %— (.+)$")
end

-- Read **Project:** from the session file header
local function read_project_dir(session_bufnr)
  local lines = vim.api.nvim_buf_get_lines(session_bufnr, 0, 20, false)
  for _, l in ipairs(lines) do
    local dir = l:match("%*%*Project:%*%* (.+)")
    if dir then
      return dir
    end
  end
  return nil
end

-- Resolve a relative file path to an absolute path (absolute tried first, then project-relative)
local function resolve_abs(file, project_dir)
  local candidate = vim.fn.fnamemodify(file, ":p"):gsub("/$", "")
  if vim.fn.filereadable(candidate) == 1 then
    return candidate
  end
  if project_dir then
    candidate = vim.fn.fnamemodify(project_dir .. "/" .. file, ":p"):gsub("/$", "")
    if vim.fn.filereadable(candidate) == 1 then
      return candidate
    end
  end
  return nil
end

-- Parse the session buffer and return a list of annotation tables
local function parse_session(session_bufnr)
  local project_dir = read_project_dir(session_bufnr)
  local lines = vim.api.nvim_buf_get_lines(session_bufnr, 0, -1, false)
  local annotations = {}
  local index = 0
  for _, line in ipairs(lines) do
    local file, start_line, end_line = parse_location(line)
    if file then
      local abs_file = resolve_abs(file, project_dir)
      if abs_file then
        index = index + 1
        table.insert(annotations, {
          file = abs_file,
          start_line = start_line,
          end_line = end_line,
          note = extract_inline_note(line),
          index = index,
        })
      end
    end
  end
  return annotations
end

-- Apply cached annotations to a single buffer
local function apply_to_buf(bufnr, annotations)
  vim.api.nvim_buf_clear_namespace(bufnr, M._ns, 0, -1)

  local buf_name = vim.api.nvim_buf_get_name(bufnr)
  local line_count = vim.api.nvim_buf_line_count(bufnr)

  for _, ann in ipairs(annotations) do
    if ann.file == buf_name then
      local lnum = ann.start_line - 1 -- 0-indexed
      if lnum >= 0 and lnum < line_count then
        local n = tostring(ann.index)
        local note_preview = ann.note and vim.fn.strcharpart(ann.note, 0, 38) or nil
        local virt_str = note_preview and (" [" .. n .. "] " .. note_preview) or (" [" .. n .. "] mole")
        -- sign_text is limited to 2 display cells; fall back to ">>" for large indices
        local sign_str = #n <= 2 and n or ">>"
        vim.api.nvim_buf_set_extmark(bufnr, M._ns, lnum, 0, {
          sign_text = sign_str,
          sign_hl_group = "DiagnosticHint",
          virt_text = { { virt_str, "Comment" } },
          virt_text_pos = "eol",
          priority = 100,
        })
      end
    end
  end
end

-- Parse session + apply extmarks to all loaded buffers
function M.apply(config, session_state)
  if not config.virtual_text then
    return
  end
  if not session_state.active or not vim.api.nvim_buf_is_valid(session_state.bufnr) then
    return
  end

  M._annotations = parse_session(session_state.bufnr)

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and bufnr ~= session_state.bufnr then
      apply_to_buf(bufnr, M._annotations)
    end
  end
end

-- Apply cached annotations to the current buffer (used on BufEnter)
function M.apply_to_current(config, session_state)
  if not config.virtual_text then
    return
  end
  if not session_state.active then
    return
  end
  local bufnr = vim.api.nvim_get_current_buf()
  if bufnr == session_state.bufnr then
    return
  end
  if vim.api.nvim_buf_is_loaded(bufnr) then
    apply_to_buf(bufnr, M._annotations)
  end
end

-- Clear all extmarks from every buffer and reset cache
function M.clear()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      vim.api.nvim_buf_clear_namespace(bufnr, M._ns, 0, -1)
    end
  end
  M._annotations = {}
end

-- Set up autocmds to keep extmarks in sync
function M.setup_autocmds(config, session_state)
  if not config.virtual_text then
    return
  end

  local group = vim.api.nvim_create_augroup("MoleMarks", { clear = true })

  -- Re-parse and re-apply whenever the session file is saved
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    buffer = session_state.bufnr,
    callback = function()
      M.apply(config, session_state)
    end,
  })

  -- Apply cached marks when entering a buffer that may be annotated
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function()
      M.apply_to_current(config, session_state)
    end,
  })
end

-- Clear marks and remove autocmds (called on session stop)
function M.teardown()
  M.clear()
  pcall(vim.api.nvim_del_augroup_by_name, "MoleMarks")
end

return M
