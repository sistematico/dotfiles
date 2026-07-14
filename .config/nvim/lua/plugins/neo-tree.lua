return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
  },
  cmd = "Neotree",
  keys = {
    { "<C-b>",      "<cmd>Neotree toggle reveal<cr>",              desc = "Explorer: toggle (arquivo atual)" },
    { "<leader>ge", "<cmd>Neotree toggle git_status<cr>",          desc = "Explorer: git status" },
    { "<leader>be", "<cmd>Neotree toggle buffers<cr>",             desc = "Explorer: buffers" },
    { "<leader>fe", "<cmd>Neotree float filesystem reveal<cr>",    desc = "Explorer: float (arquivo atual)" },
  },
  opts = {
    close_if_last_window = true,
    popup_border_style = "rounded",
    enable_git_status = true,
    enable_diagnostics = true,
    sort_case_insensitive = true,
    default_component_configs = {
      indent = {
        with_expanders = true,
        expander_collapsed = "",
        expander_expanded = "",
      },
      git_status = {
        symbols = {
          added     = "",
          modified  = "",
          deleted   = "",
          renamed   = "",
          untracked = "",
          ignored   = "",
          unstaged  = "",
          staged    = "",
          conflict  = "",
        },
      },
    },
    window = {
      position = "left",
      width = 32,
      mappings = {
        ["<space>"] = "none", -- libera <space> pro leader dentro da árvore
        ["l"]  = "open",
        ["h"]  = "close_node",
        ["<cr>"] = "open",
        ["P"]  = { "toggle_preview", config = { use_float = true } },
        ["S"]  = "open_split",
        ["s"]  = "open_vsplit",
        ["y"]  = "copy_to_clipboard",
        ["x"]  = "cut_to_clipboard",
        ["p"]  = "paste_from_clipboard",
        ["a"]  = "add",
        ["d"]  = "delete",
        ["r"]  = "rename",
        ["c"]  = "copy",
        ["m"]  = "move",
        ["R"]  = "refresh",
        ["?"]  = "show_help",
        ["<"]  = "prev_source",
        [">"]  = "next_source",
      },
    },
    filesystem = {
      follow_current_file = { enabled = true },
      use_libuv_file_watcher = true,
      hijack_netrw_behavior = "open_default",
      filtered_items = {
        visible = false, -- "H" alterna a visibilidade dos itens escondidos
        hide_dotfiles = false,
        hide_gitignored = true,
        hide_by_name = { "node_modules" },
      },
      window = {
        mappings = {
          ["H"] = "toggle_hidden",
          ["/"] = "fuzzy_finder",
          ["f"] = "filter_on_submit",
          ["<C-x>"] = "clear_filter",
        },
      },
    },
    buffers = {
      follow_current_file = { enabled = true },
    },
    git_status = {
      window = {
        position = "float",
      },
    },
  },
}
