call plug#begin()
Plug 'ghifarit53/tokyonight-vim'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
call plug#end()

syntax on
set termguicolors tabstop=2 expandtab softtabstop=2 shiftwidth=2 background=dark
highlight Normal ctermbg=NONE guibg=NONE

nnoremap <C-Left> :tabprevious<cr>
nnoremap <C-Right> :tabnext<cr>
inoremap <C-q> <esc>:qa!<cr>
nnoremap <C-q> :qa!<cr>
inoremap <C-s> <esc>:wqa<cr>
nnoremap <C-s> :wqa!<cr>
inoremap <C-o> <esc>:wa<cr>
nnoremap <C-o> :wa!<cr>
nnoremap <F6> :%!shfmt -i 2 -ci -sr -kp<return>
inoremap <F6> <esc>:%!shfmt -i 2 -ci -sr -kp<return>

let g:airline_theme = "tokyonight"
let g:tokyonight_style = 'night' " available: night, storm
let g:tokyonight_enable_italic = 1

autocmd BufReadPost *
     \ if line("'\"") > 0 && line("'\"") <= line("$") |
     \   exe "normal! g`\"" |
     \ endif

colorscheme tokyonight
