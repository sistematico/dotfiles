-- Tema padrão atual. Pra voltar pro Tokyo Night, veja tokyo-night.lua.
return {
  "ellisonleao/gruvbox.nvim",
  lazy = false,
  priority = 1000,
  opts = {
    contrast = "hard",
    transparent_mode = true,
  },
  config = function(_, opts)
    require("gruvbox").setup(opts)
    vim.cmd.colorscheme "gruvbox"
  end,
}
