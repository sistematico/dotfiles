return {
  "goolord/alpha-nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  cmd = "Alpha",
  opts = function()
    local dashboard = require("alpha.themes.dashboard")

    dashboard.section.header.val = {
      "                                                    ",
      "  ██╗  ██╗██╗   ██╗██╗███╗   ███╗                   ",
      "  ██║  ██║██║   ██║██║████╗ ████║                   ",
      "  ███████║██║   ██║██║██╔████╔██║                   ",
      "  ██╔══██║╚██╗ ██╔╝██║██║╚██╔╝██║                   ",
      "  ██║  ██║ ╚████╔╝ ██║██║ ╚═╝ ██║                   ",
      "  ╚═╝  ╚═╝  ╚═══╝  ╚═╝╚═╝     ╚═╝                   ",
      "                                                    ",
    }

    dashboard.section.buttons.val = {
      dashboard.button("f", "  Find file", ":Telescope find_files<CR>"),
      dashboard.button("r", "  Recent files", ":Telescope oldfiles<CR>"),
      dashboard.button("g", "  Find text", ":Telescope live_grep<CR>"),
      dashboard.button("e", "  Explorer", ":Neotree toggle<CR>"),
      dashboard.button("q", "  Quit", ":qa<CR>"),
    }

    return dashboard.opts
  end,
  config = function(_, opts)
    require("alpha").setup(opts)
  end,
}
