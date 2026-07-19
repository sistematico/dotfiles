return {
  'nvim-lualine/lualine.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  opts = {
    theme = 'gruvbox'
  },
  config = function(_, opts)
    local lualine = require("lualine")
    lualine.setup(opts)
  end
}
