-- ╭──────────────────────────────────────────────────────────────────────────╮
-- │  #4 -- a terminal inside nvim, in the current file's directory.          │
-- │                                                                          │
-- │  <C-\> opens a floating fish shell rooted at the directory of the file    │
-- │  you are editing (not nvim's cwd -- so it is the directory you actually   │
-- │  want to run things in). Press it again to hide it; the shell keeps       │
-- │  running, so a `npm run dev` survives being toggled away.                 │
-- ╰──────────────────────────────────────────────────────────────────────────╯
return {
  {
    "akinsho/toggleterm.nvim",
    cmd = { "ToggleTerm", "TermExec" },
    keys = {
      { [[<C-\>]], desc = "Terminal (float, file's dir)" },
      { "<leader>tt", desc = "Terminal (float)" },
      { "<leader>th", desc = "Terminal (horizontal)" },
      { "<leader>tv", desc = "Terminal (vertical)" },
      { "<leader>tp", desc = "Terminal (python)" },
      { "<leader>tn", desc = "Terminal (node)" },
    },
    opts = {
      -- Open at the directory of the current buffer. `dir` is evaluated once
      -- per terminal creation, which is what makes each new terminal land
      -- where you are rather than where nvim started.
      size = function(term)
        if term.direction == "horizontal" then
          return 15
        elseif term.direction == "vertical" then
          return vim.o.columns * 0.4
        end
      end,
      open_mapping = [[<C-\>]],
      direction = "float",
      shell = vim.fn.executable("fish") == 1 and "fish" or vim.o.shell,
      shade_terminals = false,        -- the theme is transparent; do not tint it
      start_in_insert = true,
      persist_size = true,
      persist_mode = true,
      autochdir = false,
      float_opts = {
        border = "rounded",
        width = function() return math.floor(vim.o.columns * 0.85) end,
        height = function() return math.floor(vim.o.lines * 0.8) end,
        winblend = 0,
        title_pos = "center",
      },
      highlights = {
        Normal = { link = "Normal" },
        NormalFloat = { link = "NormalFloat" },
        FloatBorder = { link = "FloatBorder" },
      },
      on_open = function(term)
        -- Retarget the shell to the current file's directory each time it is
        -- opened, so it follows you around the project.
        local dir = vim.fn.expand("%:p:h")
        if dir ~= "" and vim.fn.isdirectory(dir) == 1 then
          term:send("cd " .. vim.fn.shellescape(dir), false)
        end
        vim.cmd("startinsert!")
      end,
    },
    config = function(_, opts)
      require("toggleterm").setup(opts)
      local Terminal = require("toggleterm.terminal").Terminal

      local function float_cmd(cmd, key, desc)
        local t = Terminal:new({ cmd = cmd, direction = "float", hidden = true, close_on_exit = false })
        vim.keymap.set("n", key, function() t:toggle() end, { desc = desc })
      end

      vim.keymap.set("n", "<leader>tt", "<cmd>ToggleTerm direction=float<cr>", { desc = "Terminal (float)" })
      vim.keymap.set("n", "<leader>th", "<cmd>ToggleTerm direction=horizontal<cr>", { desc = "Terminal (horizontal)" })
      vim.keymap.set("n", "<leader>tv", "<cmd>ToggleTerm direction=vertical<cr>", { desc = "Terminal (vertical)" })
      float_cmd("python3", "<leader>tp", "Terminal (python repl)")
      float_cmd("node", "<leader>tn", "Terminal (node repl)")

      -- Send the visual selection to the running terminal -- useful with the
      -- python/node REPLs above.
      vim.keymap.set("v", "<leader>ts", function()
        require("toggleterm").send_lines_to_terminal("visual_selection", true, { args = vim.v.count })
      end, { desc = "Send selection to terminal" })
    end,
  },
}
