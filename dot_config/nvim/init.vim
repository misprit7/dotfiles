" Allows switching without saving buffer
set hidden
" Word wrap
set wrap

" Plugin stuff
filetype off
syntax on
filetype plugin indent on
set modelines=0

" set formatoptions=tcqrn1
set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab
set noshiftround

" Keeps 5 lines above cursor when scrolling with mouse
set scrolloff=5

" Backspace problems
set backspace=indent,eol,start
" Speed up scrolling
set ttyfast

" Status bar
set laststatus=2

" Display options
set showmode
set showcmd

" Bracket matching
set matchpairs+=<:>

" Show line number
set number

" Encoding
set encoding=utf-8

" Highlight matching search patterns
set hlsearch
" Enable incremental search
set incsearch
" Include matching uppercase words with lowercase search term
set ignorecase
" Include only uppercase words with uppercase search term
set smartcase

" Store info from no more than 100 files at a time, 9999 lines of text, 100kb of data. Useful for copying large amounts of data between files.
set viminfo='100,<9999,s100

let g:airline#extensions#tabline#enabled = 1

" Enable copying out of vim
autocmd VimLeave * call system("xsel -ib", getreg('+'))


" Case insensitive search
set smartcase
set ignorecase

" Mouse
set mouse=a

" Workaround to prevent vim from breaking background color in kitty
let &t_ut=''


call plug#begin('~/.config/nvim/plugged')

"Fugitive Vim Github Wrapper
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-sensible'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-commentary'

Plug 'joshdick/onedark.vim', { 'as': 'onedark' }
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

Plug 'sheerun/vim-polyglot'

Plug 'neoclide/coc.nvim', {'branch': 'release'}

call plug#end()

let g:onedark_hide_endofbuffer=1

runtime coc.vim

color onedark

" Remaps
" Scrolling
nnoremap <S-j> <C-e>
nnoremap <S-k> <C-y>

" Backspace
noremap! <C-BS> <C-w>
noremap! <C-h> <C-w>

" Switch panes
map <C-j> <C-W>j
map <C-k> <C-W>k
map <C-h> <C-W>h
map <C-l> <C-W>l

" Switch panes insert mode
imap <C-j> <C-W>j
imap <C-k> <C-W>k
imap <C-h> <C-W>h
imap <C-l> <C-W>l

" Explorer
:nmap <space>e <Cmd>CocCommand explorer<CR>

