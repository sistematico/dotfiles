return {
  'nvim-lualine/lualine.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  opts = {
    theme = 'tomorrow_night'
  },
  config = function(_, opts)
    local lualine = require("lualine")
    lualine.setup(opts)
  end
}
