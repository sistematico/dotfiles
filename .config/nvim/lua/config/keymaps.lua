-- ============================================================================
-- ATALHOS ESTILO VSCODE
-- ============================================================================

-- Salvar arquivo - CTRL+s (original: :w)
vim.keymap.set("n", "<C-s>", ":w<CR>", { desc = "Salvar arquivo" })
vim.keymap.set("i", "<C-s>", "<Esc>:w<CR>a", { desc = "Salvar arquivo (insert mode)" })

-- Sair - CTRL+q (original: :q)
vim.keymap.set("n", "<C-q>", ":q<CR>", { desc = "Sair" })

-- Comentar código - CTRL+/ (precisa do plugin Comment.nvim)
-- Original: gcc (linha) ou gc (visual mode)
vim.keymap.set("n", "<C-_>", "gcc", { desc = "Comentar linha", remap = true })
vim.keymap.set("v", "<C-_>", "gc", { desc = "Comentar seleção", remap = true })
-- Nota: <C-_> é como o terminal interpreta CTRL+/

-- ============================================================================
-- ATALHOS ADICIONAIS ESTILO VSCODE (OPCIONAL)
-- ============================================================================

-- Duplicar linha - CTRL+d (original: yyp)
-- Nota: em modo normal, <C-d> é sobrescrito abaixo por "Meia página abaixo
-- (centralizado)" (seção NAVEGAÇÃO). Duplicar linha só se aplica no insert mode.
vim.keymap.set("i", "<C-d>", "<Esc>yypa", { desc = "Duplicar linha abaixo (insert)" })

-- Mover linha para cima - ALT+k (original: ddkP)
vim.keymap.set("n", "<A-k>", ":m .-2<CR>==", { desc = "Mover linha para cima" })
vim.keymap.set("v", "<A-k>", ":m '<-2<CR>gv=gv", { desc = "Mover seleção para cima" })

-- Mover linha para baixo - ALT+j (original: ddp)
vim.keymap.set("n", "<A-j>", ":m .+1<CR>==", { desc = "Mover linha para baixo" })
vim.keymap.set("v", "<A-j>", ":m '>+1<CR>gv=gv", { desc = "Mover seleção para baixo" })

-- Desfazer - CTRL+z (original: u)
vim.keymap.set("n", "<C-z>", "u", { desc = "Desfazer" })
vim.keymap.set("i", "<C-z>", "<Esc>ua", { desc = "Desfazer (insert)" })

-- Refazer - CTRL+y (original: CTRL+r)
vim.keymap.set("n", "<C-y>", "<C-r>", { desc = "Refazer" })

-- Selecionar tudo - CTRL+a (original: ggVG)
vim.keymap.set("n", "<C-a>", "ggVG", { desc = "Selecionar tudo" })

-- ============================================================================
-- NAVEGAÇÃO
-- ============================================================================

-- PageUp/PageDown personalizados - 10 linhas (original: CTRL+u e CTRL+d)
vim.keymap.set("n", "<PageUp>", "10k", { desc = "Sobe 10 linhas" })
vim.keymap.set("n", "<PageDown>", "10j", { desc = "Desce 10 linhas" })
vim.keymap.set("v", "<PageUp>", "10k", { desc = "Sobe 10 linhas" })
vim.keymap.set("v", "<PageDown>", "10j", { desc = "Desce 10 linhas" })

-- Navegação rápida centralizada (original: CTRL+u e CTRL+d)
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Meia página acima (centralizado)" })
vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Meia página abaixo (centralizado)" })

-- ============================================================================
-- TOGGLE NÚMEROS DE LINHA
-- ============================================================================

-- Toggle números de linha (original: :set number! relativenumber!)
vim.keymap.set("n", "<leader>ln", function()
  -- Pega o estado atual
  local number = vim.wo.number
  local relativenumber = vim.wo.relativenumber
  
  -- Se qualquer um está ativo, desativa ambos
  if number or relativenumber then
    vim.wo.number = false
    vim.wo.relativenumber = false
    print("Números de linha: OFF")
  else
    -- Se ambos estão desativados, ativa ambos
    vim.wo.number = true
    vim.wo.relativenumber = true
    print("Números de linha: ON")
  end
end, { desc = "Toggle line numbers" })
