" autoload/airline/extensions/goime.vim — Airline 状态栏集成
" Airline 会自动发现此扩展（by design），无需用户手动配置

let s:loaded = 0

function! airline#extensions#goime#init(ext)
  if s:loaded
    return
  endif
  let s:loaded = 1

  " 在 section A（最左侧）添加 GoIME 状态
  call a:ext.add_statusline_func('airline#extensions#goime#apply')
endfunction

function! airline#extensions#goime#apply(...)
  " 只在状态栏中显示
  if &g:statusline =~# 'goime'
    return ''
  endif
  " 返回 GoIME 状态文本
  return goime#status()
endfunction

" 高亮
function! airline#extensions#goime#highlight(...)
  " 使用 airline 默认高亮
endfunction
