call plug#begin()
Plug 'ghifarit53/tokyonight-vim'
call plug#end()

syntax on
set termguicolors tabstop=2 expandtab softtabstop=2 shiftwidth=2 background=dark
highlight Normal ctermbg=NONE guibg=NONE

let g:tokyonight_style = 'night' " available: night, storm
let g:tokyonight_enable_italic = 1

colorscheme tokyonight
