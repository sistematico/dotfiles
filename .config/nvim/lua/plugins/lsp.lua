return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "mason-org/mason.nvim",
    "mason-org/mason-lspconfig.nvim",
    "hrsh7th/cmp-nvim-lsp",
  },
  config = function()
    local capabilities = require("cmp_nvim_lsp").default_capabilities()

    -- Diagnostics na coluna de sinais + texto virtual discreto
    vim.diagnostic.config({
      severity_sort = true,
      float = { border = "rounded" },
      virtual_text = { spacing = 2, prefix = "●" },
      signs = {
        text = {
          [vim.diagnostic.severity.ERROR] = "",
          [vim.diagnostic.severity.WARN] = "",
          [vim.diagnostic.severity.INFO] = "",
          [vim.diagnostic.severity.HINT] = "",
        },
      },
    })

    -- Keymaps aplicados somente em buffers com LSP ativo
    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("user-lsp-attach", { clear = true }),
      callback = function(args)
        local opts = { buffer = args.buf }
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, vim.tbl_extend("force", opts, { desc = "Ir para definição" }))
        vim.keymap.set("n", "gD", vim.lsp.buf.declaration, vim.tbl_extend("force", opts, { desc = "Ir para declaração" }))
        vim.keymap.set("n", "gr", vim.lsp.buf.references, vim.tbl_extend("force", opts, { desc = "Ver referências" }))
        vim.keymap.set("n", "gi", vim.lsp.buf.implementation, vim.tbl_extend("force", opts, { desc = "Ver implementações" }))
        vim.keymap.set("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", opts, { desc = "Documentação (hover)" }))
        vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, vim.tbl_extend("force", opts, { desc = "Renomear símbolo" }))
        vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, vim.tbl_extend("force", opts, { desc = "Code action" }))
        vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, vim.tbl_extend("force", opts, { desc = "Mostrar diagnóstico" }))
        vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, vim.tbl_extend("force", opts, { desc = "Diagnóstico anterior" }))
        vim.keymap.set("n", "]d", vim.diagnostic.goto_next, vim.tbl_extend("force", opts, { desc = "Próximo diagnóstico" }))
      end,
    })

    -- Configuração padrão aplicada a todos os servidores (nova API nativa vim.lsp.config)
    vim.lsp.config("*", {
      capabilities = capabilities,
    })

    -- Go
    vim.lsp.config("gopls", {
      settings = {
        gopls = {
          gofumpt = true,
          staticcheck = true,
          usePlaceholders = true,
          analyses = { unusedparams = true },
        },
      },
    })

    -- Shell script
    vim.lsp.config("bashls", {
      filetypes = { "sh", "bash" },
    })

    -- TypeScript / JavaScript (+ integração com Vue via @vue/typescript-plugin)
    local vue_typescript_plugin_ok, vue_language_server_path = pcall(function()
      return require("mason-registry").get_package("vue-language-server"):get_install_path()
        .. "/node_modules/@vue/language-server"
    end)

    vim.lsp.config("ts_ls", {
      filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "vue" },
      init_options = vue_typescript_plugin_ok and {
        plugins = {
          {
            name = "@vue/typescript-plugin",
            location = vue_language_server_path,
            languages = { "vue" },
          },
        },
      } or nil,
    })

    -- Vue.js (Volar em modo híbrido, delega o TypeScript puro para o ts_ls acima)
    -- Precisa do --tsdk apontando para o TypeScript do projeto, senão o vue_ls
    -- pode resolver uma versão incompatível (ex.: TypeScript 7 / tsgo).
    vim.lsp.config("vue_ls", {
      cmd = function(dispatchers, config)
        local cmd = { "vue-language-server", "--stdio" }
        local tsdk = (config.root_dir or vim.fn.getcwd()) .. "/node_modules/typescript/lib"
        if vim.fn.isdirectory(tsdk) == 1 then
          table.insert(cmd, "--tsdk=" .. tsdk)
        end
        return vim.lsp.rpc.start(cmd, dispatchers, { cwd = config.cmd_cwd, env = config.cmd_env })
      end,
    })
  end,
}
