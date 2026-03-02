local M = {}

M.defaults = {
  -- Directory where session markdown files are created
  session_dir = vim.fn.stdpath("data") .. "/mole",

  -- What to capture from the visual selection:
  --   "location" => file path + line range
  --   "snippet"  => file path + line range + selected text in fenced code block
  capture_mode = "snippet",

  -- Open the side panel automatically when starting a session
  auto_open_panel = true,

  -- Custom session name. nil = timestamp, string = use as name, function = call to get name
  session_name = nil,

  -- Show vim.notify messages
  notify = true,

  -- Picker for resume: "auto" (telescope → snacks → vim.ui.select), "telescope", "snacks", or "select"
  picker = "auto",

  -- Keybindings
  keys = {
    annotate = "<leader>ma",
    start_session = "<leader>ms",
    stop_session = "<leader>mq",
    resume_session = "<leader>mr",
    toggle_window = "<leader>mw",
    jump_to_location = { "<CR>", "gd" },
    next_annotation = "]a",
    prev_annotation = "[a",
  },

  -- Floating window appearance
  window = {
    width = 0.3,
  },

  -- Inline input popup appearance
  input = {
    width = 50,
    border = "rounded",
    expand_key = "<C-e>",
  },

  -- Callback functions that return the lines written to the session file
  -- Each receives relevant context and must return a table of strings (lines)
  format = {
    header = function(info)
      return {
        "# " .. info.title,
        "",
        "**File:** " .. info.file_path,
        "**Started:** " .. info.timestamp,
        "**Project:** " .. info.cwd,
        "",
        "---",
      }
    end,
    footer = function(info)
      return {
        "",
        "---",
        "",
        "**Ended:** " .. info.timestamp,
      }
    end,
    resumed = function(info)
      return {
        "",
        "---",
        "",
        "**Resumed:** " .. info.timestamp,
        "",
        "---",
        "",
      }
    end,
  },
}

function M.apply(user_config)
  local config = vim.deepcopy(M.defaults)
  if user_config then
    config = vim.tbl_deep_extend("force", config, user_config)
  end
  return config
end

return M
