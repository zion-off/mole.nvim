local M = {}

-- Find the highest existing annotation number and return the next one.
-- Using max rather than count means deletions, reorderings, or manual edits
-- that break the pattern never produce duplicate numbers.
local function next_annotation_number(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local max = 0
  for _, line in ipairs(lines) do
    local n = line:match("^(%d+)%. %*%*`")
    if n then
      max = math.max(max, tonumber(n))
    end
  end
  return max + 1
end

---@param session_state table { active, file_path, bufnr }
---@param capture_mode string "location" or "snippet"
---@param selection table { file, start_line, end_line, text?, filetype? }
---@param note string
function M.append(session_state, capture_mode, selection, note)
  local location = string.format("`%s:%d-%d`", selection.file, selection.start_line, selection.end_line)
  if selection.start_line == selection.end_line then
    location = string.format("`%s:%d`", selection.file, selection.start_line)
  end

  local n = next_annotation_number(session_state.bufnr)
  local lines = { "" }
  local note_lines = note ~= "" and vim.split(note, "\n") or {}

  if #note_lines == 0 then
    table.insert(lines, string.format("%d. **%s**", n, location))
  elseif #note_lines == 1 then
    table.insert(lines, string.format("%d. **%s** — %s", n, location, note_lines[1]))
  else
    table.insert(lines, string.format("%d. **%s**", n, location))
    table.insert(lines, "")
    for _, nl in ipairs(note_lines) do
      table.insert(lines, nl ~= "" and ("   " .. nl) or "")
    end
  end

  if capture_mode == "snippet" and selection.text then
    local lang = selection.filetype or ""
    table.insert(lines, "   ```" .. lang)
    for _, line in ipairs(vim.split(selection.text, "\n")) do
      table.insert(lines, "   " .. line)
    end
    table.insert(lines, "   ```")
  end

  local bufnr = session_state.bufnr
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, line_count, line_count, false, lines)
  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd("silent write")
  end)

  local window = require("mole.window")
  window.refresh(bufnr)
end

return M
