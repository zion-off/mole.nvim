# mole.nvim

<img width="1142" height="865" alt="mole" src="https://github.com/user-attachments/assets/704fed19-b389-414b-952d-998d55f83207" />

&nbsp;

like moleskine, or a mole (that's watching your moves).

code annotation sessions for neovim. select code, jot a note, and build a markdown file of annotations as you debug or trace a complex flow in your code.

## how it works

1. start a session — a markdown file is created and shown in a side panel
2. select code in visual mode and hit the annotate keybinding
3. an inline popup appears — type your note and press `<CR>` to save, `<Esc>` to cancel
   - press `<C-e>` to expand into a full multiline floating buffer — confirms with `<C-CR>` or `<leader><CR>`
4. annotations are appended to the session file as a numbered markdown list — hit `<CR>` on an annotation in the side panel to jump to that location in your code
5. stop the session when you're done

each annotation records the file path and line range. press `<Tab>` in either input mode to toggle between **location** mode (reference only) and **snippet** mode (includes the selected code in a fenced block).

## requirements

- neovim >= 0.9
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim)

## installation

### lazy.nvim

```lua
{
  "zion-off/mole.nvim",
  dependencies = { "MunifTanjim/nui.nvim" },
  opts = {},
}
```

### packer.nvim

```lua
use {
  "zion-off/mole.nvim",
  requires = { "MunifTanjim/nui.nvim" },
  config = function()
    require("mole").setup({})
  end,
}
```

### mini.deps

```lua
MiniDeps.add({
  source = "zion-off/mole.nvim",
  depends = { "MunifTanjim/nui.nvim" },
})
require("mole").setup({})
```

### manual

clone the repo into your neovim packages directory:

```sh
git clone https://github.com/zion-off/mole.nvim \
  ~/.local/share/nvim/site/pack/plugins/start/mole.nvim
```

then add `require("mole").setup({})` to your config. make sure [nui.nvim](https://github.com/MunifTanjim/nui.nvim) is also installed.

## configuration

these are the defaults — pass any overrides to `setup()`:

```lua
require("mole").setup({
  -- where session files are saved
  session_dir = vim.fn.stdpath("data") .. "/mole", -- ~/.local/share/nvim/mole

  -- "location" = file path + line range
  -- "snippet" = file path + line range + selected text in a fenced code block
  capture_mode = "snippet",

  -- open the side panel automatically when starting a session
  auto_open_panel = true,

  -- custom session name: nil = timestamp, string = fixed name, function = called to get name
  session_name = nil,

  -- show vim.notify messages
  notify = true,

  -- show numbered gutter signs and EOL virtual text on annotated lines (opt-in)
  virtual_text = false,

  -- picker for resume: "auto" (telescope → snacks → vim.ui.select), "telescope", "snacks", or "select"
  picker = "auto",

  -- keybindings
  keys = {
    annotate = "<leader>ma",        -- visual mode
    start_session = "<leader>ms",   -- normal mode
    stop_session = "<leader>mq",    -- normal mode
    resume_session = "<leader>mr",  -- normal mode
    toggle_window = "<leader>mw",   -- normal mode
    jump_to_location = { "<CR>", "gd" }, -- in side panel
    next_annotation = "]a",              -- in side panel
    prev_annotation = "[a",              -- in side panel
  },

  -- side panel
  window = {
    width = 0.3, -- fraction of editor width
  },

  -- inline input popup
  input = {
    width = 50,
    border = "rounded",
    expand_key = "<C-e>", -- expand to a multiline floating buffer
  },

  -- callbacks that return lines written to the session file
  -- each receives an info table and must return a table of strings (lines)
  -- return {} to skip a section entirely
  format = {
    -- info: { title, file_path, cwd, timestamp }
    header = function(info)
      return {
        "# " .. info.title,
        "",
        "**File:** " .. info.file_path,
        "**Started:** " .. info.timestamp,
        "**Project:** " .. info.cwd, -- used to resolve file paths when jumping to locations from a different project
        "",
        "---",
      }
    end,
    -- info: { timestamp }
    footer = function(info)
      return {
        "",
        "---",
        "",
        "**Ended:** " .. info.timestamp,
      }
    end,
    -- info: { timestamp }
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
})
```

## commands & keybindings

| command / key           | mode        | description                              |
| ----------------------- | ----------- | ---------------------------------------- |
| `:MoleStart`            | normal      | start a new annotation session           |
| `:MoleStop`             | normal      | stop the current session                 |
| `:MoleResume`           | normal      | resume a previous session                |
| `:MoleToggle`           | normal      | toggle the side panel                    |
| `<leader>ma`            | visual      | annotate the current selection           |
| `<Tab>`                 | input popup | toggle location / snippet mode           |
| `<C-e>`                 | input popup | expand to multiline floating buffer      |
| `<C-CR>` / `<leader><CR>` | expanded  | save note                                |
| `<Esc>` / `q`           | expanded    | cancel                                   |
| `<CR>` / `gd`           | side panel  | jump to annotation location              |
| `]a`                    | side panel  | next annotation                          |
| `[a`                    | side panel  | previous annotation                      |

## output format

annotations are saved as a numbered markdown list. in **location** mode:

```markdown
1. **`src/main.lua:12-18`** — TODO: refactor this loop
```

in **snippet** mode:

````markdown
2. **`src/main.lua:12-18`** — TODO: refactor this loop
   ```lua
   for i = 1, #items do
     process(items[i])
   end
   ```
````

multiline notes (from the expanded input) are written as continuation paragraphs:

```markdown
3. **`src/main.lua:42`**

   first line of the note
   second line
```

when `virtual_text = true`, each annotated line in the source buffer shows its annotation number in the gutter and a short note preview at the end of the line.

session files are stored in `~/.local/share/nvim/mole/` by default (follows XDG via `stdpath("data")`).

## license

MIT
