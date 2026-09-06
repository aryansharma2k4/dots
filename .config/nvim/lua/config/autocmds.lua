local function augroup(name)
  return vim.api.nvim_create_augroup("cfg_" .. name, { clear = true })
end
local au = vim.api.nvim_create_autocmd

-- Flash the text you just yanked. The cheapest possible confirmation that the
-- motion grabbed what you meant.
au("TextYankPost", {
  group = augroup("yank_flash"),
  callback = function()
    vim.hl.on_yank({ higroup = "IncSearch", timeout = 150 })
  end,
})

-- Return to the line you were on when you last had this file open.
au("BufReadPost", {
  group = augroup("last_position"),
  callback = function(ev)
    local exclude = { "gitcommit", "gitrebase" }
    if vim.tbl_contains(exclude, vim.bo[ev.buf].filetype) then
      return
    end
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    local lcount = vim.api.nvim_buf_line_count(ev.buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
      vim.cmd("normal! zz")
    end
  end,
})

-- Relative numbers are for aiming motions, so they are only useful in normal
-- mode in the focused window. Everywhere else they are noise, and in a
-- terminal buffer they are actively wrong.
local numbers = augroup("relative_numbers")
au({ "BufEnter", "FocusGained", "InsertLeave", "WinEnter" }, {
  group = numbers,
  callback = function()
    if vim.wo.number and vim.api.nvim_get_mode().mode ~= "i" then
      vim.wo.relativenumber = true
    end
  end,
})
au({ "BufLeave", "FocusLost", "InsertEnter", "WinLeave" }, {
  group = numbers,
  callback = function()
    if vim.wo.number then
      vim.wo.relativenumber = false
    end
  end,
})

-- Close scratch/list buffers with a bare `q` instead of :q.
au("FileType", {
  group = augroup("quick_close"),
  pattern = {
    "help", "man", "qf", "lspinfo", "startuptime", "checkhealth",
    "notify", "query", "dap-float", "grug-far", "neotest-output",
  },
  callback = function(ev)
    vim.bo[ev.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = ev.buf, silent = true })
  end,
})

-- Terminal buffers: no numbers, no sign column, straight into insert.
au("TermOpen", {
  group = augroup("terminal"),
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = "no"
    vim.opt_local.spell = false
    vim.cmd.startinsert()
  end,
})

-- Strip trailing whitespace on save, but leave the cursor where it was.
au("BufWritePre", {
  group = augroup("trim_whitespace"),
  callback = function(ev)
    if vim.bo[ev.buf].filetype == "markdown" then
      return -- two trailing spaces is a hard line break in markdown
    end
    -- Only touch a real, editable file. Writing a scratch buffer (:checkhealth
    -- output, a diff view, a plugin's readonly pane) would otherwise throw
    -- E21 "Cannot make changes, modifiable is off" out of a BufWritePre hook.
    if not vim.bo[ev.buf].modifiable or vim.bo[ev.buf].readonly or vim.bo[ev.buf].buftype ~= "" then
      return
    end
    local view = vim.fn.winsaveview()
    pcall(function() vim.cmd([[keeppatterns %s/\s\+$//e]]) end)
    vim.fn.winrestview(view)
  end,
})

-- Create the parent directory when saving to a path that does not exist yet.
au("BufWritePre", {
  group = augroup("mkdir"),
  callback = function(ev)
    if ev.match:match("^%w%w+:[\\/][\\/]") then
      return -- a URL-ish path (oil://, fugitive://); not ours to create
    end
    vim.fn.mkdir(vim.fn.fnamemodify(vim.uv.fs_realpath(ev.match) or ev.match, ":p:h"), "p")
  end,
})

-- Keep splits proportional when the OS window is resized -- which happens every
-- time a hyprland tiling change moves this window.
au("VimResized", {
  group = augroup("resize"),
  callback = function()
    local tab = vim.api.nvim_get_current_tabpage()
    vim.cmd("tabdo wincmd =")
    vim.api.nvim_set_current_tabpage(tab)
  end,
})

-- Reload a file that changed on disk (a git checkout, a formatter, the other
-- half of a split-brain edit) without being asked.
au({ "FocusGained", "TermClose", "TermLeave" }, {
  group = augroup("checktime"),
  callback = function()
    if vim.o.buftype ~= "nofile" then
      vim.cmd("checktime")
    end
  end,
})

-- Turn on spell + wrap for prose, off everywhere else.
au("FileType", {
  group = augroup("prose"),
  pattern = { "markdown", "gitcommit", "text" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
})

-- Language-specific indentation. Two spaces is the community default for all
-- of these; the global 4 stays for C, C++, Python and Go.
au("FileType", {
  group = augroup("indent_width"),
  pattern = { "javascript", "typescript", "javascriptreact", "typescriptreact", "json", "jsonc", "yaml", "html", "css", "scss", "lua", "vue" },
  callback = function()
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
    vim.opt_local.softtabstop = 2
  end,
})

-- Go uses real tabs, by language convention and by gofmt's insistence.
au("FileType", {
  group = augroup("indent_go"),
  pattern = "go",
  callback = function()
    vim.opt_local.expandtab = false
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
  end,
})
