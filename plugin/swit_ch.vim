" -----------------------------------------------------------------------------
" swit_ch.vim - Switch between C/C++ impl, header and test files
" Author: Jordan Yu (https://github.com/Stymphalian)
" Version: 1.0
" License: MIT (see LICENSE attached with the source)
" -----------------------------------------------------------------------------

if exists('g:loaded_swit_ch_vim') | finish | endif
let s:save_cpo = &cpo " save user coptions
set cpo&vim " reset them to defaults

" Configurable options
" --------------

" Tells us which c++ extension to look for when switching between files
let g:swit_ch_vim_cxxExtensions = ["c", "cc", "cpp"]
let g:swit_ch_vim_hxxExtensions = ["h", "hpp"]

" Pass these directories to the -E argument of the 'fd' command
" Each entry is a separate -E <arg> that will be passed to the <fd> 
" command line
let g:swit_ch_vim_excludeDirectories = []

" Whether to search for the .git root directory and begin the search for
" files from the root directory
let g:swit_ch_vim_searchFromGitRoot = 1

" Use default autocmd group mappings. If true then we automatically
" setup bindings when the buffer filetype is cpp, and add some key 
" binndings to switch between them.
let g:swit_ch_vim_useDefaultMappings = 1

" --------------
" End Configurable options

function! s:ParseFilenameToParts(filename) abort
  let parts = {
        \'original': fnamemodify(a:filename, ':t'), 
        \'extension': fnamemodify(a:filename, ':e'), 
        \'basename': '',
        \'type': '' 
        \}
  let parts.basename = substitute(
        \l:parts['original'],'.' . parts['extension'], '', '')
  let parts.basename = substitute(parts['basename'], '_test', '', '')
  let extension = expand('%:e')

  if index(g:swit_ch_vim_cxxExtensions, extension) >= 0
    if stridx(fnamemodify(a:filename, ':t'), '_test') !=# -1
      let parts.type = 'test'
    else
      let parts.type = 'impl'
    endif
  elseif index(g:swit_ch_vim_hxxExtensions, l:extension) >= 0
    let parts.type = "header"
  endif

  return parts
endfunction

function! s:LenListComparator(a, b) abort
  if strlen(a:a) ==# strlen(a:b)
    return 0
  elseif strlen(a:a) < strlen(a:b)
    return -1
  else
    return 1
  endif
endfunction

function! s:RemoveNewLinesFromList(theList) abort
  let newList = []
  for result in a:theList
    let newList = add(newList, substitute(result, '\n', '', 'g'))
  endfor
  return newList
endfunction

function! s:PresentResultsAndChooseFile(findResults) abort
  if len(a:findResults) ==# 0
    echom "Failed to find file to switch to."
    return [-1, ""]
  elseif len(a:findResults) ==# 1
    return [0, a:findResults[0]]
  else 
    " show a list for the user to pick a choice
    let findResultsSorted = <SID>RemoveNewLinesFromList(a:findResults)
    let findResultsSorted = sort(findResultsSorted, '<SID>LenListComparator')

    let findResultsWithNumber = ['Select which file to open: ']
    let i = 0
    for r3 in findResultsSorted
      let fileWithNumber = "[" . l:i . "] " . r3
      let findResultsWithNumber = add(findResultsWithNumber, fileWithNumber)
      let i += 1
    endfor

    let selection = inputlist(findResultsWithNumber)
    if selection >=# 0 && selection <# len(findResultsSorted)
      return [0, findResultsSorted[selection]]
    else
      echom ' Error: Selection ' . selection . ' is out of range.'
    endif

  endif

  return [-1, '']
endfunction

function! s:BuildSearchCommand(fileParts, switchToType) abort
  if !executable('fd')
    echom 'Error: swit_ch depends on the "fd" command line'
    return [-1, ""]
  endif

  " Form the filename regex to serach for
  if a:switchToType ==# "header"
    let searchName = '/' . a:fileParts['basename'] . '.(' . join(g:swit_ch_vim_hxxExtensions, '|') . ')$'
  elseif a:switchToType ==# "impl"
    let searchName = '/' . a:fileParts['basename'] . '.(' . join(g:swit_ch_vim_cxxExtensions, '|') . ')$'
  elseif a:switchToType ==# "test"
    let searchName = '/' . a:fileParts['basename'] . '_test.(' . join(g:swit_ch_vim_cxxExtensions, '|') . ')$'
  else
    echom "Unrecognized switch to type"
    return [-1, ""]
  endif

  " Which directory to search under
  let searchDir = ' . '
  if g:swit_ch_vim_searchFromGitRoot ==# 1 && executable('git')
    let gitDir = substitute(system('git rev-parse --show-toplevel'), '\n', '', 'g')
    let hasGit = v:shell_error ==# 0
    if hasGit !=# 0
      let searchDir = ' ' . gitDir . ' '
    endif
  endif

  " If there are any directories to exclude from our search
  let excludeDirs = ''
  if len(g:swit_ch_vim_excludeDirectories) >=# 1
    let i = 0
    for dir in g:swit_ch_vim_excludeDirectories
      let excludeDirs = ' -E' . shellescape(dir) . ' '
    endfor
  endif
  echom excludeDirs

  " -p option is so that we can apply our search pattern on the full filepaths
  " searchName - is the regex for the file
  " searchDir - either the current pwd of the vim process, or the git roto
  " excludeDir - optionally a list of -E <exclude_dir> options
  let cmd = 'fd -p ' . shellescape(searchName) . searchDir . excludeDirs
  return [0, cmd]
endfunction

function! swit_ch#SwitchBetweenFiles(switchToType) abort
  " Function to switch to the 'other' file, which could be:
  " the <file>_test.cxx, <file>.cxx, or <file>.hxx
  let fileParts = <SID>ParseFilenameToParts(expand("%:p"))

  if fileParts['type'] ==# a:switchToType
    echom "Not switching to same type of file"
    return ""
  endif

  let result = <SID>BuildSearchCommand(fileParts, a:switchToType)
  if result[0] !=# 0
    return ""
  else
    let cmd = result[1]
  endif
  
  " Run the command and try to find the file
  let findResults = systemlist(cmd)
  if v:shell_error !=# 0 || len(findResults) ==# 0
    echom "Couldn't find " . a:switchToType . " for file " . fileParts['original']
    return ""
  endif

  " Found the file, open it in a buffer
  let result = <SID>PresentResultsAndChooseFile(findResults)
  if result[0] !=# 0
    return ""
  else
    execute "edit " . result[1]
  endif

  return ""
endfunction

" Define some >Plug> mappings to allow the use to set up their own key
" bindings
nnoremap <silent> <Plug>switch_Impl : execute swit_ch#SwitchBetweenFiles('impl')<CR>
nnoremap <silent> <Plug>switch_Test : execute swit_ch#SwitchBetweenFiles('test')<CR>
nnoremap <silent> <Plug>switch_Header : execute swit_ch#SwitchBetweenFiles('header')<CR>
"command! -complete=command SwitchToImpl call swit_ch#SwitchBetweenFiles('impl')
"command! -complete=command SwitchToHeader call swit_ch#SwitchBetweenFiles('header')
"command! -complete=command SwitchToTest call swit_ch#SwitchBetweenFiles('test')

if g:swit_ch_vim_useDefaultMappings ==# 1
  augroup swit_ch_vim_c_group
    autocmd!
    "autocmd FileType cpp nnoremap <silent> <buffer> <leader>lc :execute swit_ch#SwitchBetweenFiles('impl')<CR>
    "autocmd FileType cpp nnoremap <silent> <buffer> <leader>lt :execute swit_ch#SwitchBetweenFiles('test')<CR>
    "autocmd FileType cpp nnoremap <silent> <buffer> <leader>lh :execute swit_ch#SwitchBetweenFiles('header')<CR>
    autocmd FileType cpp nmap <silent> <buffer> <leader>lc <Plug>switch_Impl
    autocmd FileType cpp nmap <silent> <buffer> <leader>lt <Plug>switch_Test
    autocmd FileType cpp nmap <silent> <buffer> <leader>lh <Plug>switch_Header
  augroup END
endif

" g:varame - global
" s:varname - script local
" w:varname - window local
" t:varname - tab local
" b:varname - buffer local
" l:varname - function local
" a:varname - function argument
" v:varname - VIM defined variable

let &cpo = s:save_cpo " and restore after
unlet s:save_cpo
let g:loaded_swit_ch_vim = 1
