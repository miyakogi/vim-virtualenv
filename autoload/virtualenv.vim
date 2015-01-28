function! virtualenv#activate(name) "{{{1
    let name = a:name
    if len(name) == 0  "Figure out the name based on current file
        if isdirectory($VIRTUAL_ENV)
            let name = fnamemodify($VIRTUAL_ENV, ':t')
        elseif isdirectory($PROJECT_HOME)
            let fn = expand('%:p')
            let pat = '^'.$PROJECT_HOME.'/'
            if fn =~ pat
                let name = fnamemodify(substitute(fn, pat, '', ''), ':h')
            endif
        endif
    endif
    if len(name) == 0  "Couldn't figure it out, so DIE
        return
    endif
    let l:base = g:virtualenv_directory . '/' . name
    let l:bin = l:base . '/bin'
    let l:script = l:bin . '/activate'
    if !filereadable(l:script)
        return 0
    endif
    call virtualenv#deactivate()
    let g:virtualenv_path = $PATH

    " Prepend bin to PATH, but only if it's not there already
    " (activate_this does this also, https://github.com/pypa/virtualenv/issues/14)
    if $PATH[:len(l:bin)] != l:bin.':'
        let $PATH = l:bin.':'.$PATH
    endif

    let l:python_path = l:bin . '/python'
    let l:python_ver = system(l:python_path . ' -V')[7:9]
    let l:python_ver_major = l:python_ver[0]
    let g:virtualenv_name = name

    " Re-implementation of activate_this.py
    python << EOF
import vim
import sys
import os
import shlex
from subprocess import check_output

prev_sys_path = list(sys.path)
activate = vim.eval('l:script')

old_os_path = os.environ['PATH']
os.environ['PATH'] = os.path.dirname(os.path.abspath(activate)) + os.pathsep + old_os_path
base = os.path.dirname(os.path.dirname(os.path.abspath(activate)))
if sys.platform == 'win32':
    site_packages = os.path.join(base, 'Lib', 'site-packages')
else:
    py_site_ver = vim.eval('l:python_ver')
    py_base = vim.eval('l:base')
    site_packages = os.path.join(py_base, 'lib', 'python'+py_site_ver, 'site-packages')
import site
site.addsitedir(site_packages)
sys.real_prefix = sys.prefix
sys.prefix = base
# Move the added items to the front of the path:
new_sys_path = []
for item in list(sys.path):
    if item not in prev_sys_path:
        new_sys_path.append(item)
        sys.path.remove(item)
sys.path[:0] = new_sys_path
EOF
endfunction

function! virtualenv#deactivate() "{{{1
    python << EOF
import vim, sys
try:
    sys.path[:] = prev_sys_path
    del(prev_sys_path)
    # os.environ['PYTHONPATH'] = prev_pythonpath
    # del(prev_pythonpath)
except:
    pass
EOF
    if exists('g:virtualenv_path')
        let $PATH = g:virtualenv_path
    endif
    unlet! g:virtualenv_name
    unlet! g:virtualenv_path
endfunction

function! virtualenv#list() "{{{1
    for name in virtualenv#names('')
        echo name
    endfor
endfunction

function! virtualenv#statusline() "{{{1
    if exists('g:virtualenv_name')
        return substitute(g:virtualenv_stl_format, '\C%n', g:virtualenv_name, 'g')
    else
        return ''
    endif
endfunction

function! virtualenv#names(prefix) "{{{1
    let venvs = []
    for dir in split(glob(g:virtualenv_directory.'/'.a:prefix.'*'), '\n')
        if !isdirectory(dir)
            continue
        endif
        let fn = dir.'/bin/activate'
        if !filereadable(fn)
            continue
        endif
        call add(venvs, fnamemodify(dir, ':t'))
    endfor
    return venvs
endfunction
