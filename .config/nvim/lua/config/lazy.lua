-- Bootstrap lazy.nvim. Cloned on first launch; after that this is a no-op path
-- check costing one stat call.
--
-- nvim 0.12 ships its own vim.pack, but lazy.nvim is kept here for its
-- lazy-loading: nearly every plugin below is loaded on a filetype, a key, or an
-- event rather than at startup, which is the difference between a ~30ms and a
-- ~300ms cold start with this many plugins.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local out = vim.fn.system({
    "git", "clone", "--filter=blob:none", "--branch=stable",
    "https://github.com/folke/lazy.nvim.git", lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = { { import = "plugins" } },
  install = { colorscheme = { "tokyonight-night", "habamax" } },
  checker = { enabled = true, notify = false },  -- check for updates quietly
  change_detection = { notify = false },
  ui = {
    border = "rounded",
    backdrop = 100,
  },
  performance = {
    rtp = {
      -- Builtin vim plugins we never use. Each one skipped is runtimepath
      -- scanning and sourcing that does not happen at startup.
      disabled_plugins = {
        "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin",
        "netrwPlugin", "rplugin", "matchit", "matchparen",
      },
    },
  },
})
