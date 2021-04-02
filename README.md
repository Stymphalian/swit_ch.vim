# swit_ch - vim plugin to switch between c++ header, impl, and test files

## Install
Install using whatever vim plugin manager you use. I've been using vim-plug
The plugin depends on `git` and `fd`
```
call plug#begin('~/.vim/plugged')
Plug 'https://github.com/Stymphalian/swit_ch.vim'
call plug#end()
```

## How it works
swit_ch will look for the corresponding C/C++ header, implementation. and test
file starting from the top level .git root directory. It will try to match a 
regex to find the to the correct basename of your filename.

For example:
If current filename is /my/git/repo/sub/dir/my_file.cpp, and you want to 
switch to your header file. `my_file` is the basename of the file and so 
swit_ch will do a system call to `fd my_file.(h|hpp) /my/git/repo` to find the 
header file. If one is found it will edit the file in a new buffer.
If there are mulitple matches for the file it will present a selection screen
for you to choose which file to open.

## Keymapping and Configuration
The plugin setups an autocmd for cpp FileTypes and by default adds key mappings.

```
<leader>lc  - to switch to the cpp/implementation file
<leader>lh  - to switch to the .h/header file
<leader>lt  - to switch to the test file
```

Please read the vim doc for other configuration.
