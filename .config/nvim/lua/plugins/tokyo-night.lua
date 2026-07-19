-- Instalado mas inativo. Pra voltar a usar: mude lazy=false e priority=1000
-- aqui, e desative o vim.cmd.colorscheme "gruvbox" em gruvbox.lua.
return {
  "folke/tokyonight.nvim",
  lazy = true,
  opts = {
    -- "night" matches the background kitty currently uses (#1a1b26)
    style = "night",
    transparent = true,
    styles = {
      sidebars = "transparent",
      floats = "transparent",
    },
  },
  config = function(_, opts)
    require("tokyonight").setup(opts)
  end,
}
