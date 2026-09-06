-- ╭──────────────────────────────────────────────────────────────────────────╮
-- │  Keymaps                                                                 │
-- │                                                                          │
-- │  Leader is <Space>. Every leader binding is labelled in which-key, so     │
-- │  pressing <Space> alone and waiting is the live version of this file.     │
-- │  Plugin-owned bindings live with their plugin in lua/plugins/.            │
-- ╰──────────────────────────────────────────────────────────────────────────╯

local map = vim.keymap.set

-- ── the file tree <-> editor toggle ──────────────────────────────────────────
-- One key, both directions. In the tree it jumps back to the file you were
-- editing; anywhere else it jumps into the tree, opening it first if it is
-- closed. `wincmd p` is the previous window, which is the right target even
-- when you have several splits open on the right.
local function toggle_explorer_focus()
  if vim.bo.filetype == "neo-tree" then
    vim.cmd.wincmd("p")
  else
    vim.cmd("Neotree focus filesystem left")
  end
end
map("n", "<leader>e", toggle_explorer_focus, { desc = "Explorer <-> editor" })
map("n", "<C-e>", toggle_explorer_focus, { desc = "Explorer <-> editor" })
map("n", "<leader>E", "<cmd>Neotree toggle filesystem left<cr>", { desc = "Explorer show/hide" })
map("n", "<leader>ge", "<cmd>Neotree float git_status<cr>", { desc = "Explorer: git status" })
map("n", "<leader>be", "<cmd>Neotree toggle buffers right<cr>", { desc = "Explorer: open buffers" })

-- ── buffers as tabs, and cycling them ────────────────────────────────────────
-- <Tab> / <S-Tab> walk the bufferline left to right.
-- Note: this costs <C-i> (jump-forward), since a terminal sends the same byte
-- for both. <C-o> for jump-back is unaffected.
map("n", "<Tab>", "<cmd>BufferLineCycleNext<cr>", { desc = "Next buffer" })
map("n", "<S-Tab>", "<cmd>BufferLineCyclePrev<cr>", { desc = "Prev buffer" })
map("n", "<S-l>", "<cmd>BufferLineCycleNext<cr>", { desc = "Next buffer" })
map("n", "<S-h>", "<cmd>BufferLineCyclePrev<cr>", { desc = "Prev buffer" })
-- Reorder rather than jump.
map("n", "<leader>bl", "<cmd>BufferLineMoveNext<cr>", { desc = "Move buffer right" })
map("n", "<leader>bh", "<cmd>BufferLineMovePrev<cr>", { desc = "Move buffer left" })
map("n", "<leader>bp", "<cmd>BufferLineTogglePin<cr>", { desc = "Pin buffer" })
map("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Close buffer" })
map("n", "<leader>bo", "<cmd>BufferLineCloseOthers<cr>", { desc = "Close other buffers" })
-- Jump straight to a numbered tab.
for i = 1, 9 do
  map("n", "<leader>" .. i, "<cmd>BufferLineGoToBuffer " .. i .. "<cr>", { desc = "Buffer " .. i })
end

-- ── window navigation ────────────────────────────────────────────────────────
map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })
map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Taller" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Shorter" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Narrower" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Wider" })
map("n", "<leader>ws", "<C-w>s", { desc = "Split horizontal" })
map("n", "<leader>wv", "<C-w>v", { desc = "Split vertical" })
map("n", "<leader>wq", "<C-w>q", { desc = "Close window" })
map("n", "<leader>w=", "<C-w>=", { desc = "Equalise windows" })

-- ── editing ──────────────────────────────────────────────────────────────────
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })

-- Move the selected lines up/down, reindenting as they go.
map("v", "J", ":m '>+1<cr>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<cr>gv=gv", { desc = "Move selection up" })
-- Stay in visual mode after shifting, so you can shift again.
map("v", "<", "<gv")
map("v", ">", ">gv")
-- Paste over a selection without the selection clobbering your register.
map("x", "p", [["_dP]], { desc = "Paste without yanking" })
-- Keep the cursor put when joining, and centred when jumping.
map("n", "J", "mzJ`z", { desc = "Join lines, keep cursor" })
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")

-- Break the undo sequence at punctuation, so one `u` does not swallow a whole
-- paragraph you typed without leaving insert mode.
map("i", ",", ",<c-g>u")
map("i", ".", ".<c-g>u")
map("i", ";", ";<c-g>u")

map("n", "<leader>fs", "<cmd>write<cr>", { desc = "Save file" })
map("n", "<leader>fS", "<cmd>wall<cr>", { desc = "Save all" })
map("n", "<leader>qq", "<cmd>qall<cr>", { desc = "Quit all" })
map("n", "<leader>qw", "<cmd>wqall<cr>", { desc = "Save all and quit" })

-- ── diagnostics ──────────────────────────────────────────────────────────────
map("n", "]d", function() vim.diagnostic.jump({ count = 1 }) end, { desc = "Next diagnostic" })
map("n", "[d", function() vim.diagnostic.jump({ count = -1 }) end, { desc = "Prev diagnostic" })
map("n", "]e", function() vim.diagnostic.jump({ count = 1, severity = vim.diagnostic.severity.ERROR }) end, { desc = "Next error" })
map("n", "[e", function() vim.diagnostic.jump({ count = -1, severity = vim.diagnostic.severity.ERROR }) end, { desc = "Prev error" })
map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Line diagnostics" })

-- ── quickfix ─────────────────────────────────────────────────────────────────
map("n", "]q", "<cmd>cnext<cr>", { desc = "Next quickfix" })
map("n", "[q", "<cmd>cprev<cr>", { desc = "Prev quickfix" })

-- ── terminal mode ────────────────────────────────────────────────────────────
-- Escape out of a terminal buffer without fighting the shell for <Esc>.
map("t", "<C-x>", "<C-\\><C-n>", { desc = "Terminal: to normal mode" })
map("t", "<C-h>", "<cmd>wincmd h<cr>", { desc = "Window left" })
map("t", "<C-j>", "<cmd>wincmd j<cr>", { desc = "Window down" })
map("t", "<C-k>", "<cmd>wincmd k<cr>", { desc = "Window up" })
map("t", "<C-l>", "<cmd>wincmd l<cr>", { desc = "Window right" })
