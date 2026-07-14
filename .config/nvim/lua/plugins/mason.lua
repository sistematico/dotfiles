return {
  {
    "mason-org/mason.nvim",
    opts = {
      ui = {
        border = "rounded",
      },
    },
  },
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = {
      "mason-org/mason.nvim",
      "neovim/nvim-lspconfig",
    },
    opts = {
      ensure_installed = {
        "vue_ls",  -- Vue.js (Volar)
        "ts_ls",   -- TypeScript / JavaScript
        "gopls",   -- Go
        "bashls",  -- Shell script
      },
    },
  },
  {
    -- Instala automaticamente formatters/linters que não são LSPs
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "mason-org/mason.nvim" },
    opts = {
      ensure_installed = {
        -- Go
        "goimports",
        "gofumpt",
        "golangci-lint",
        -- Vue / TypeScript / JavaScript
        "prettierd",
        "eslint_d",
        -- Shell
        "shfmt",
        "shellcheck",
      },
    },
  },
}
