# Configuração Neovim

Config pessoal baseada em [lazy.nvim](https://github.com/folke/lazy.nvim), com
LSP, formatação, lint e autocomplete para **Vue.js (TypeScript)**, **Go** e
**Shell script**, gerenciados via [mason.nvim](https://github.com/mason-org/mason.nvim).

Testado em Neovim 0.12.

## Estrutura

```
.
├── init.lua                     -- entrypoint, só chama config.lazy
└── lua
    ├── options.lua               -- opções gerais + keymaps de janela
    ├── lastplace.lua              -- volta o cursor pra última posição editada
    ├── config
    │   ├── autocmds.lua           -- Alpha/Neo-tree ao abrir diretório, etc.
    │   ├── keymaps.lua            -- atalhos estilo VSCode
    │   └── lazy.lua               -- bootstrap do lazy.nvim
    └── plugins
        ├── tokyo-night.lua        -- colorscheme
        ├── telescope.lua          -- busca de arquivos/grep
        ├── mason.lua              -- mason.nvim + mason-lspconfig + mason-tool-installer
        ├── lsp.lua                -- nvim-lspconfig (LSPs)
        ├── conform.lua            -- formatação (conform.nvim)
        ├── lint.lua               -- lint (nvim-lint)
        ├── cmp.lua                -- autocomplete (nvim-cmp)
        └── neo-tree.lua           -- explorador de arquivos (neo-tree.nvim)
```

## O que foi adicionado

| Linguagem  | LSP           | Formatter              | Linter          |
|------------|---------------|-------------------------|-----------------|
| Vue (TS)   | `vue_ls` + `ts_ls` (com plugin `@vue/typescript-plugin`) | `prettierd`     | `eslint_d`      |
| Go         | `gopls`       | `goimports` + `gofumpt` | `golangci-lint` |
| Shell      | `bashls`      | `shfmt`                 | `shellcheck`    |

Tudo isso é instalado automaticamente pelo Mason na primeira vez que o Neovim
abrir (via `ensure_installed` em `mason.lua`) — não precisa rodar nada manualmente.

### LSP (`lua/plugins/lsp.lua`)

- Usa a API nativa do Neovim 0.11+ (`vim.lsp.config` / `vim.lsp.enable`), com
  `mason-lspconfig` cuidando de habilitar automaticamente os servers listados
  em `ensure_installed`.
- `gopls`: `gofumpt`, `staticcheck` e `usePlaceholders` habilitados.
- `bashls`: ativo para `sh` e `bash`.
- Vue.js roda em **modo híbrido**: o `vue_ls` (Volar) cuida de template/CSS, e
  o `ts_ls` cuida do TypeScript dentro dos arquivos `.vue` através do plugin
  `@vue/typescript-plugin` (localizado automaticamente dentro do pacote
  `vue-language-server` do Mason).
  - **Importante:** o `vue_ls` precisa achar o TypeScript do **projeto**
    (`node_modules/typescript`) para funcionar — a config já resolve isso
    automaticamente passando `--tsdk=<root>/node_modules/typescript/lib`
    quando a pasta existe. Se um projeto Vue não tiver `typescript` instalado
    localmente (`npm install -D typescript`), o `vue_ls` pode falhar ao subir.
- Diagnostics com ícones no signcolumn, texto virtual discreto e float com
  borda arredondada.

Keymaps de LSP (ativos só em buffers com LSP anexado, via `LspAttach`):

| Atalho        | Ação                              |
|---------------|------------------------------------|
| `gd`          | Ir para definição                  |
| `gD`          | Ir para declaração                 |
| `gr`          | Ver referências                    |
| `gi`          | Ver implementações                 |
| `K`           | Hover / documentação               |
| `<leader>rn`  | Renomear símbolo                   |
| `<leader>ca`  | Code action (normal e visual)      |
| `<leader>e`   | Mostrar diagnóstico da linha       |
| `[d` / `]d`   | Diagnóstico anterior / próximo     |

### Formatação (`lua/plugins/conform.lua`)

Formata automaticamente ao salvar (`format_on_save`), com fallback para o
formatter do próprio LSP se não houver um formatter dedicado.

| Atalho       | Ação                                  |
|--------------|-----------------------------------------|
| `<leader>lf` | Formatar buffer (normal) ou seleção (visual) |

### Lint (`lua/plugins/lint.lua`)

Roda automaticamente em `BufReadPost`, `BufWritePost` e `InsertLeave`. Os
diagnósticos aparecem junto com os do LSP (mesmo signcolumn/virtual text).

### Autocomplete (`lua/plugins/cmp.lua`)

`nvim-cmp` com fontes LSP, snippets (`LuaSnip` + `friendly-snippets`), buffer
e path.

| Atalho              | Ação                                  |
|---------------------|-----------------------------------------|
| `<C-Space>`         | Abrir/forçar completions                |
| `<C-j>` / `<C-k>`   | Próximo / item anterior                 |
| `<Tab>` / `<S-Tab>` | Próximo item ou pular snippet           |
| `<CR>`              | Confirmar seleção                       |
| `<C-e>`             | Cancelar completions                    |
| `<C-b>` / `<C-f>`   | Scroll na documentação                  |

`<C-b>`/`<C-f>` do cmp só valem com o menu de completions **aberto** (modo
insert); fora dele, `<C-b>` alterna o Neo-tree (ver abaixo) — não há conflito
real entre os dois.

### Explorador de arquivos (`lua/plugins/neo-tree.lua`)

[neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim), no lugar do
netrw (que já vinha desabilitado em `options.lua`). Ele já era referenciado
em `config/autocmds.lua` (abre sozinho ao iniciar o Neovim num diretório, e
fecha o Neovim se sobrar só ele na tela) — agora está de fato instalado e
configurado.

| Atalho        | Ação                                          |
|---------------|-----------------------------------------------|
| `<C-b>`       | Toggle explorer (revela o arquivo atual na árvore) |
| `<leader>ge`  | Toggle painel de git status                    |
| `<leader>be`  | Toggle painel de buffers abertos                |
| `<leader>fe`  | Abre o explorer numa janela flutuante           |

Dentro da árvore (`window.mappings` em `neo-tree.lua`):

| Tecla        | Ação                                   |
|--------------|-----------------------------------------|
| `<CR>` / `l` | Abrir arquivo/pasta                     |
| `h`          | Fechar pasta                            |
| `P`          | Preview flutuante do arquivo             |
| `s` / `S`    | Abrir em split vertical / horizontal     |
| `a`          | Criar arquivo/pasta                      |
| `d`          | Deletar                                  |
| `r`          | Renomear                                 |
| `c` / `m`    | Copiar / mover                           |
| `y` / `x` / `p` | Copiar / recortar / colar (clipboard interno do neo-tree) |
| `R`          | Refresh                                  |
| `H`          | Mostrar/esconder arquivos ocultos (dotfiles) |
| `/`          | Fuzzy finder dentro da árvore            |
| `<C-x>`      | Limpar filtro do fuzzy finder            |
| `<`  / `>`   | Alternar entre fontes (filesystem/buffers/git_status) |
| `?`          | Ajuda com todos os binds                 |

Configurações mais relevantes em `opts`:

- `filesystem.filtered_items.hide_gitignored = true` — some o que está no
  `.gitignore`; dotfiles ficam visíveis (`hide_dotfiles = false`), mas dá pra
  esconder tudo de novo com `H` dentro da árvore.
  `hide_by_name` já ignora `node_modules`.
- `filesystem.follow_current_file.enabled = true` e o mesmo em `buffers` —
  a árvore sempre destaca o arquivo do buffer ativo.
  `use_libuv_file_watcher = true` mantém a árvore em sincronia com mudanças
  no disco sem precisar dar refresh manual.
  `hijack_netrw_behavior = "open_default"` faz `nvim <diretório>` ou `:e
  <diretório>` abrirem o neo-tree em vez do netrw.
- `enable_git_status` + `enable_diagnostics` mostram status do git e
  diagnósticos do LSP/lint direto na árvore.
- `close_if_last_window = true` fecha o Neovim se o neo-tree for a última
  janela (reforça o autocmd de `QuitPre` que já existia).
- Ícones (`nvim-web-devicons`) e símbolos de git precisam de uma **Nerd
  Font** no terminal pra renderizar direito.

## Outros atalhos (já existentes)

### Janelas / navegação (`lua/options.lua`)

| Atalho                | Ação                          |
|-----------------------|-------------------------------|
| `<C-h/j/k/l>`         | Navegar entre janelas          |
| `<leader>h`           | Limpar highlight de busca      |

### Estilo VSCode (`lua/config/keymaps.lua`)

| Atalho          | Ação                                  |
|-----------------|-----------------------------------------|
| `<C-s>`         | Salvar arquivo                          |
| `<C-q>`         | Sair                                    |
| `<C-_>`         | Comentar linha/seleção                  |
| `<C-d>` (insert)| Duplicar linha                          |
| `<A-j>` / `<A-k>` | Mover linha para baixo / cima          |
| `<C-z>` / `<C-y>` | Desfazer / refazer                     |
| `<C-a>`         | Selecionar tudo                          |
| `<PageUp/Down>` | Sobe/desce 10 linhas                     |
| `<C-u>` / `<C-d>` (normal) | Meia página (centralizada)     |
| `<leader>ln`    | Toggle números de linha (absoluto+relativo) |

> `<C-d>` em modo normal era mapeado duas vezes (duplicar linha e meia
> página); a segunda sempre vencia, então a versão "duplicar linha" nunca
> rodava de fato em modo normal. Removida a duplicata — `<C-d>` normal agora
> só faz meia página centralizada; duplicar linha continua funcionando em
> insert mode.

### Telescope (`lua/plugins/telescope.lua`)

| Atalho        | Ação              |
|---------------|-------------------|
| `<C-p>` / `<leader>ff` | Buscar arquivos |
| `<leader>fg`  | Live grep          |
| `<leader>fb`  | Buffers            |
| `<leader>fr`  | Arquivos recentes  |
| `<leader>fh`  | Help tags          |
| `<leader>fd`  | Diagnostics        |

Dentro do Telescope (modo insert): `<C-k>`/`<C-j>` navegam a lista, `<C-q>`
envia seleção pra quickfix list.

## Atualizando

- **Plugins**: `:Lazy` abre o painel do lazy.nvim — `U` atualiza todos, `S`
  sincroniza (instala/remove conforme o lockfile). `:Lazy update` faz o mesmo
  via linha de comando.
- **LSP servers / formatters / linters**: `:Mason` abre o painel do Mason
  para ver o que está instalado, atualizar (`U`) ou instalar algo novo (`i`).
  `:MasonToolsUpdate` atualiza tudo que está em `ensure_installed`
  (`lua/plugins/mason.lua`).
- **Adicionar uma nova ferramenta**: edite o `ensure_installed` correspondente
  em `lua/plugins/mason.lua` (LSP vs. formatter/linter) e reinicie o Neovim —
  a instalação é automática.

## Requisitos

- Neovim >= 0.11 (usa a API nativa `vim.lsp.config`/`vim.lsp.enable`).
- `git`, `node`/`npm` e `go` disponíveis no `$PATH` (Mason usa `npm` para
  instalar os servers de Vue/TS e `go install` para o `gopls`/`golangci-lint`).
- Para o `vue_ls` funcionar em um projeto Vue, o projeto precisa ter
  `typescript` como dependência local (`npm install -D typescript`).
