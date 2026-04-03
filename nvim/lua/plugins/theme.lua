return {
  {
    "datsfilipe/vesper.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require('vesper').setup({
        transparent = false, -- We want it solid black, not see-through
        italics = {
          comments = true,
          keywords = true,
          functions = true,
          strings = true,
        },
      })
      vim.cmd.colorscheme("vesper")

      -- Force OLED Black (#000000) on all background elements
      local oled_groups = {
        "Normal", "NormalNC", "SignColumn", "StatusLine", 
        "StatusLineNC", "EndOfBuffer", "MsgArea", "NvimTreeNormal",
        "TabLineFill", "Folded"
      }
      
      for _, group in ipairs(oled_groups) do
        vim.api.nvim_set_hl(0, group, { fg = "NONE", bg = "#000000" })
      end
    end
  }
}
