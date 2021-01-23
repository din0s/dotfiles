let &t_ut=''
let g:airline_theme='jellybeans'

" enable indentation plugin
filetype plugin indent on

" tab = 4 spaces
set tabstop=4
set softtabstop=4
set shiftwidth=4

" utf8 encoding
set encoding=utf-8

" enable mouse
set mouse=a

set autoindent
set expandtab
set hlsearch
set incsearch
set number
set showmatch
set title
set wildmenu

" syntax highlighting
syntax enable

" vim-plug plugins
call plug#begin('~/.vim/plugged')

Plug 'vim-airline/vim-airline'

Plug 'vim-airline/vim-airline-themes'

Plug 'patstockwell/vim-monokai-tasty'

call plug#end()

let g:vim_monokai_tasty_italic = 1
colorscheme vim-monokai-tasty

