
return {
  {
    "datsfilipe/vesper.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("vesper").setup({
        transparent = false,
      })

      vim.cmd.colorscheme("vesper")

      -- Force solid black background
      vim.api.nvim_set_hl(0, "Normal", { bg = "#000000" })
      vim.api.nvim_set_hl(0, "NormalNC", { bg = "#000000" })
      vim.api.nvim_set_hl(0, "SignColumn", { bg = "#000000" })
      vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = "#000000" })
    end
  }
}
