"source $HOMEvim-calendar/credentials.vim

set number
set mouse=a
set numberwidth=1
set clipboard=unnamed
set showcmd 
set ruler 
set encoding=utf-8
set showmatch
set relativenumber
set laststatus=2
set backspace=2
set modifiable
set guifont=Consolas:h13
set nocompatible
set tabstop=2
set shiftwidth=2
set expandtab
set splitbelow
set splitright
set background=dark
set autochdir
set noerrorbells visualbell t_vb=
autocmd GUIEnter * set visualbell t_vb=
let &t_ti.="\e[1 q"
let &t_SI.="\e[5 q"
let &t_EI.="\e[1 q"
let &t_te.="\e[0 q"

"set sw=2
"set noshowmode

filetype plugin on
syntax enable
syntax on

		"-------------------------------------- Plugins --------------------------------------"

call plug#begin('~/.vim/vimfiles/autoload')

	"Themes
	Plug 'morhetz/gruvbox'

	"IDE
	Plug 'scrooloose/nerdtree'
	Plug 'ctrlpvim/ctrlp.vim'
	Plug 'jelera/vim-javascript-syntax'
	Plug 'mxw/vim-jsx'
	Plug 'elzr/vim-json'
  Plug 'jiangmiao/auto-pairs'

call plug#end()


"Colors
colorscheme gruvbox
let g:gruvbox_contrast_dark = "hard"


"NERDTreeConfig
let g:NERDTreeChDirMode=2
let NERDTreeQuitOnOpen=1

"CTRL P cofiguration
let g:ctrlp_working_path_mode = 'r'
let g:ctrlp_custom_ignore = 'node_modules\|DS_Store\|git'
let g:ctrlp_user_command = ['.git/', 'git --git-dir=%s/.git ls-files -oc --exclude-standard']

"Related to org mode
let g:calendar_cache_directory = expand('$HOME/vim-calendar')


		"------------------------------------ Personal commands ------------------------------------
let mapleader = " "

nmap <Leader>j 6j
vmap <Leader>j 6j

nmap <Leader>k 6k
vmap <Leader>k 6k

nmap <Leader>h 4b
vmap <Leader>h 4b

nmap <Leader>l 4w
vmap <Leader>l 4w

nmap zz z<CR>6k6j

nmap <Leader>w :w<CR>
nmap <Leader>q :q<CR>
nmap <Leader>wq :wq<CR>

nmap <Leader>nt : NERDTreeFind<CR>
nmap <Leader>p : CtrlP<CR>

"For reloading automatically
nmap <Leader>r :source $HOME/vimrc<CR>

"For better { and [ typing
inoremap <C-J> {}<left>
inoremap <C-K> []<left>

"For manipulate splits There are more, but I will add them when I learn how to manage splits better
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

"For selecting blocks of content
nmap dij di{
nmap cij di{
nmap yij di{
nmap vij vi{

nmap dik di[
nmap cik di[
nmap yik di[
nmap vik vi[

nmap daj da{
nmap caj da{
nmap yaj da{
nmap vaj va{

nmap dak da[
nmap cak da[
nmap yak da[
nmap vak va[
