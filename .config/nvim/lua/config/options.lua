local opt = vim.opt
local g = vim.g

-- Leader must be set before lazy.nvim loads anything that maps against it.
g.mapleader = " "
g.maplocalleader = "\\"

-- ── numbers ──────────────────────────────────────────────────────────────────
-- Hybrid numbering: the current line shows its absolute number, every other
-- line shows its distance. That distance is the count you type for a motion,
-- so `8k` stops being arithmetic.
opt.number = true
opt.relativenumber = true
opt.signcolumn = "yes"          -- never let diagnostics shift the text sideways
opt.cursorline = true
opt.cursorlineopt = "number,line"

-- ── indentation ──────────────────────────────────────────────────────────────
opt.expandtab = true
opt.shiftwidth = 4
opt.tabstop = 4
opt.softtabstop = 4
opt.smartindent = true
opt.breakindent = true
opt.shiftround = true

-- ── search ───────────────────────────────────────────────────────────────────
opt.ignorecase = true
opt.smartcase = true            -- ...unless you type a capital
opt.hlsearch = true
opt.incsearch = true
opt.inccommand = "split"        -- live preview of :s/// results

-- ── window behaviour ─────────────────────────────────────────────────────────
opt.splitright = true           -- vertical splits open to the right
opt.splitbelow = true
opt.splitkeep = "screen"        -- text does not jump when a split opens
opt.scrolloff = 8               -- keep 8 lines of context above/below the cursor
opt.sidescrolloff = 8
opt.wrap = false
opt.linebreak = true

-- ── appearance ───────────────────────────────────────────────────────────────
opt.termguicolors = true
opt.pumheight = 12              -- cap the completion popup so it never fills the screen
opt.pumblend = 0
opt.winblend = 0
opt.showmode = false            -- lualine already shows the mode
opt.cmdheight = 0               -- noice draws the cmdline as a popup, so reclaim the row
opt.laststatus = 3              -- one statusline across all splits, not one per split
opt.conceallevel = 2
opt.fillchars = {
  foldopen = "",
  foldclose = "",
  fold = " ",
  foldsep = " ",
  diff = "╱",
  eob = " ",                    -- no ~ on the empty lines past end-of-buffer
}
opt.listchars = { tab = "→ ", trail = "·", nbsp = "␣", extends = "›", precedes = "‹" }
opt.list = true

-- ── folds, via treesitter ────────────────────────────────────────────────────
opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldtext = ""
opt.foldlevel = 99              -- everything open on load; fold deliberately with zc
opt.foldcolumn = "0"

-- ── files and undo ───────────────────────────────────────────────────────────
opt.undofile = true             -- undo history survives closing the file
opt.undolevels = 10000
opt.swapfile = false
opt.backup = false
opt.writebackup = false
opt.autoread = true
opt.confirm = true              -- ask to save instead of refusing to quit

-- ── responsiveness ───────────────────────────────────────────────────────────
opt.updatetime = 200            -- drives CursorHold: diagnostics, git signs, word highlight
opt.timeoutlen = 400            -- how long which-key waits before showing itself
opt.ttimeoutlen = 10
opt.redrawtime = 1500
opt.lazyredraw = false          -- must stay off: it fights the cursor animation

-- ── completion and diagnostics behaviour ─────────────────────────────────────
opt.completeopt = "menu,menuone,noselect,fuzzy"
opt.shortmess:append({ W = true, I = true, c = true, C = true })

-- ── clipboard ────────────────────────────────────────────────────────────────
-- Deferred: touching the clipboard at startup makes nvim shell out to
-- wl-copy before the first frame, which is a visible delay on a cold start.
vim.schedule(function()
  opt.clipboard = "unnamedplus"
end)

-- ── misc ─────────────────────────────────────────────────────────────────────
opt.mouse = "a"
opt.mousemoveevent = true       -- lets bufferline show hover state on the tabs
opt.virtualedit = "block"       -- visual-block can select past end of line
opt.jumpoptions = "view"
opt.sessionoptions = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp", "folds" }
opt.wildmode = "longest:full,full"
opt.spelllang = { "en" }
opt.formatoptions = "jcroqlnt"

-- Providers we do not use. Disabling them skips a subprocess probe per start.
g.loaded_perl_provider = 0
g.loaded_ruby_provider = 0
g.loaded_node_provider = 0
g.loaded_python3_provider = 0
g.loaded_netrw = 1              -- neo-tree replaces it
g.loaded_netrwPlugin = 1
