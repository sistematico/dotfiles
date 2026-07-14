-- Abrir a tela de apresentação (Alpha) quando nvim é iniciado com um diretório
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function(data)
    local is_directory = vim.fn.isdirectory(data.file) == 1

    if is_directory then
      vim.cmd.cd(data.file)
      vim.cmd("Alpha")
      vim.cmd("Neotree show")
      vim.cmd("wincmd p") -- devolve o foco para o Alpha
    end
  end,
})

-- Fechar o nvim se Neo-tree for a última janela
vim.api.nvim_create_autocmd("QuitPre", {
  callback = function()
    local invalid_win = {}
    local wins = vim.api.nvim_list_wins()
    for _, w in ipairs(wins) do
      local bufname = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w))
      if bufname:match("neo%-tree") ~= nil then
        table.insert(invalid_win, w)
      end
    end
    if #invalid_win == #wins then
      vim.cmd("qall")
    end
  end,
})
