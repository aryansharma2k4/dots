return {
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters = opts.formatters or {}

      for _, ft in ipairs({
        "c",
        "cpp",
        "cs",
        "cuda",
        "java",
        "javascript",
        "javascriptreact",
        "objc",
        "objcpp",
        "proto",
        "typescript",
        "typescriptreact",
      }) do
        opts.formatters_by_ft[ft] = { "clang_format" }
      end

      opts.formatters.clang_format = vim.tbl_deep_extend("force", opts.formatters.clang_format or {}, {
        prepend_args = {
          "--style={BasedOnStyle: LLVM, IndentWidth: 4, TabWidth: 4, UseTab: Never, BreakBeforeBraces: Allman}",
        },
      })
    end,
  },
}
