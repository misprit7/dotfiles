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

" Fast redrawing during macros
set lazyredraw

" Bracket matching
" set matchpairs+=<:>

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

" Set folds to default indent, but open by default
set foldmethod=indent
set nofoldenable

" Store info from no more than 100 files at a time, 9999 lines of text, 100kb of data. Useful for copying large amounts of data between files.
set viminfo='100,<9999,s100

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

" Plug 'github/copilot.vim'

" imap <silent><script><expr> <C-S> copilot#Accept("\<CR>")
" let g:copilot_no_tab_map = v:true

" let g:onedark_hide_endofbuffer=1
" Plug 'joshdick/onedark.vim', { 'as': 'onedark' }
Plug 'dracula/vim', {'as':'dracula'}

" let g:airline#extensions#tabline#enabled = 1
" Plug 'vim-airline/vim-airline'
" Plug 'vim-airline/vim-airline-themes'

Plug 'nvim-lualine/lualine.nvim'
Plug 'nvim-tree/nvim-web-devicons'

Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim', { 'tag': '0.1.8' }
nnoremap gb <cmd>Telescope buffers<cr>
nnoremap gf <cmd>Telescope find_files<cr>
nnoremap ga <cmd>Telescope live_grep<cr>

let g:polyglot_disabled = ['lilypond']
Plug 'sheerun/vim-polyglot'

let g:tex_flavor='latex'
let g:vimtex_view_method='zathura'
let g:vimtex_quickfix_mode=0
let g:vimtex_compiler_engine='lualatex'
" set conceallevel=1
" let g:tex_conceal='abdmg'
Plug 'lervag/vimtex'

let g:UltiSnipsExpandTrigger = '<insert>'
let g:UltiSnipsJumpForwardTrigger = '<tab>'
let g:UltiSnipsJumpBackwardTrigger = '<s-tab>'
let g:python3_host_prog = '/usr/bin/python3'
Plug 'sirver/ultisnips'

let g:coc_global_extensions = ['coc-explorer', 'coc-clangd']
Plug 'neoclide/coc.nvim', {'branch': 'release'}

let g:vimspector_enable_mappings = 'HUMAN'
Plug 'puremourning/vimspector'

call plug#end()

lua << EOF
require('lualine').setup {
  options = {
    icons_enabled = true,
    theme = 'auto',
    component_separators = { left = '', right = ''},
    section_separators = { left = '', right = ''},
    disabled_filetypes = {
      statusline = {},
      winbar = {},
    },
    ignore_focus = {},
    always_divide_middle = true,
    always_show_tabline = true,
    globalstatus = false,
    refresh = {
      statusline = 100,
      tabline = 100,
      winbar = 100,
    }
  },
  sections = {
    lualine_a = {'mode'},
    lualine_b = {'branch', 'diff', 'diagnostics'},
    lualine_c = {{'filename', path=1}},
    lualine_x = {'encoding', 'fileformat', 'filetype'},
    lualine_y = {'progress'},
    lualine_z = {'location'}
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {'filename'},
    lualine_x = {'location'},
    lualine_y = {},
    lualine_z = {}
  },
  tabline = {
        lualine_a = {
          {
            'buffers',
            mode = 4,
          },
        },
        lualine_c = {},
        lualine_b = { 'lsp_progress', },
        lualine_x = {},
        lualine_y = { 'grapple', },
        lualine_z = { 'tabs' }
      },
  winbar = {},
  inactive_winbar = {},
  extensions = {}
}
EOF


" nmap <Leader>p <Plug>VimspectorToggleBreakpoint
" nmap <Leader>o <Plug>VimspectorContinue

" color onedark
colorscheme dracula

" Spell checker
" setlocal spell
autocmd BufRead,BufNewFile *.md setlocal spell
autocmd BufRead,BufNewFile *.tex setlocal spell
set spelllang=nl,en_us
inoremap <C-l> <c-g>u<Esc>[s1z=`]a<c-g>u

" Adds lilypond configuration
filetype off
set runtimepath+=~/.config/nvim/lilypond
filetype on

" Get rid of lag editing LaTeX files
let g:tex_fast= ""
" https://github.com/lervag/vimtex/issues/1727
" https://jchain.github.io/vim-gets-slow-when-editing-latex-file.html
let g:loaded_matchparen=1
let g:vimtex_matchparen_enabled = 0

" Register preloads
let @c="/******************************************************************************\n * \n ******************************************************************************/"

" Remaps
" Leader
let mapleader = " "

runtime coc.vim

" Scrolling
nnoremap <S-j> <C-e>
nnoremap <S-k> <C-y>

" Line movements
nnoremap <S-H> ^
nnoremap <S-L> $

" Switch tab
nnoremap <S-h> gT
nnoremap <S-l> gt

" Backspace
noremap! <C-BS> <C-w>
noremap! <C-h> <C-w>

" Switch panes
map <Leader>j <C-W>j
map <Leader>k <C-W>k
map <Leader>h <C-W>h
map <Leader>l <C-W>l

map <Leader>f :bn<cr>
map <Leader>s :bp<cr>
map <Leader>d :bp<bar>sp<bar>bn<bar>bd<CR>

map <Leader>> <C-w>>
map <Leader>< <C-w><
map <Leader>+ <C-w>+
map <Leader>- <C-w>-

" Explorer
nmap <Leader>e <Cmd>CocCommand explorer<CR>
nmap <Leader>w <Cmd>CocCommand explorer --sources=buffer+<CR>

" Clipboard
map gy "+y
map gp "+p

" Filename
nmap <C-n> 1<C-g>

" Search
nmap <C-f> /
imap <C-f> <Esc>/

" Visual mode with remapped CTRL-V
nnoremap B <C-v>

" End of word defaults
" nnoremap e E
" nnoremap w W
" nnoremap b B

" Makes * not automatically go to the next result
nnoremap * *``

" End/beginning of line
nnoremap E $
nnoremap W ^


