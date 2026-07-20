-- Instalado mas inativo. Pra voltar a usar: mude lazy=false e priority=1000
-- aqui, e desative o vim.cmd.colorscheme "tokyonight" em tokyo-night.lua.
return {
  "ellisonleao/gruvbox.nvim",
  lazy = true,
  opts = {
    contrast = "hard",
    transparent_mode = true,
  },
  config = function(_, opts)
    require("gruvbox").setup(opts)
  end,
}
