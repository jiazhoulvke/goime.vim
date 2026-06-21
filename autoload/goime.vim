" autoload/goime.vim — GoIME Vim8 核心逻辑
" 提供连接管理、协议通信、候选窗渲染和状态栏接口

" ============================================================================
" 模块级状态（每个 Vim 会话独立）
" ============================================================================

let s:channel = v:null           " Vim channel 句柄
let s:connected = 0            " 是否已连接
let s:chinese_mode = 1         " 1=中文模式，0=英文模式
let s:schemes = []             " 可用输入方案列表
let s:active_scheme = ''       " 当前方案
let s:page_size = 5            " 每页候选数
let s:buffer = ''              " 接收缓冲区（行协议拼接）
let s:popup_win = -1           " 候选窗窗口 ID
let s:candidate_pages = 1      " 总页数
let s:candidate_current_page = 0  " 当前页
let s:prev_insert_mode = 0     " 上次调用 on_insert_enter 是否已在插入模式
let s:preedit_text = ''        " 当前 preedit 文本（用于候选窗显示）

" ============================================================================
" 工具函数
" ============================================================================

" goime#_socket_path 获取 socket 文件路径
" goime#_socket_exists 检查路径是否为已存在的 socket 文件
function! goime#_socket_exists(path)
  return getftype(a:path) ==# 'socket'
endfunction

" goime#_socket_path 获取 socket 文件路径
function! goime#_socket_path()
  if g:goime_socket_path !=# ''
    return g:goime_socket_path
  endif
  let runtime_dir = $XDG_RUNTIME_DIR
  if runtime_dir !=# '' && goime#_socket_exists(runtime_dir . '/goime.sock')
    return runtime_dir . '/goime.sock'
  endif
  let uid = system('id -u')
  let uid = substitute(uid, '\n', '', 'g')
  return '/tmp/goime-' . uid . '.sock'
endfunction

" goime#_find_binary 查找 goimed 可执行文件
function! goime#_find_binary()
  if g:goime_binary !=# ''
    return g:goime_binary
  endif
  if executable('goimed')
    return 'goimed'
  endif
  return ''
endfunction

" goime#_json_encode 将字典编码为 JSON 字符串
" Vim 8.2+ 有 json_encode()，降级方案用简单实现
function! goime#_json_encode(dict)
  if exists('*json_encode')
    return json_encode(a:dict)
  endif
  " 简单实现：仅支持本插件所需的 JSON 格式
  let parts = []
  for [key, value] in items(a:dict)
    if type(value) == type(0)
      call add(parts, '"' . key . '":' . value)
    elseif type(value) == type("")
      call add(parts, '"' . key . '":"' . escape(value, '"\') . '"')
    elseif type(value) == type([])
      let arr = '[' . join(map(copy(value), {_, v -> '"' . escape(v, '"\') . '"'}), ',') . ']'
      call add(parts, '"' . key . '":' . arr)
    endif
  endfor
  return '{' . join(parts, ',') . '}'
endfunction

" goime#_json_decode 将 JSON 字符串解码为字典
function! goime#_json_decode(str)
  if exists('*json_decode')
    try
      return json_decode(a:str)
    catch
      return {}
    endtry
  endif
  return {}
endfunction

" goime#_log 调试日志
function! goime#_log(msg)
  if exists('g:goime_debug') && g:goime_debug
    echom '[goime] ' . a:msg
  endif
endfunction

" ============================================================================
" 连接管理
" ============================================================================

" goime#connect 连接到 goimed 守护进程
function! goime#connect()
  if s:connected
    return
  endif

  let socket_path = goime#_socket_path()

  " Socket 不存在时尝试启动 goimed
  if !goime#_socket_exists(socket_path)
    let binary = goime#_find_binary()
    if binary ==# ''
      call goime#_log('goimed 未找到，请先安装：go install github.com/jiazhoulvke/goime/cmd/goimed@latest')
      return
    endif
    " 异步启动 goimed
    if has('job')
      call job_start([binary], {'out_cb': {_, data -> goime#_log(data)}})
    else
      call system(binary . ' &')
    endif
    " 等待 socket 就绪（最多 1s）
    let waited = 0
    while !goime#_socket_exists(socket_path) && waited < 1000
      sleep 50m
      let waited += 50
    endwhile
    if !goime#_socket_exists(socket_path)
      call goime#_log('goimed 启动超时')
      return
    endif
  endif

  " 连接 Unix Socket
  try
    if has('nvim')
      return
    endif
    if exists('*sockconnect')
      let ch = sockconnect('unix', socket_path, {'mode': 'raw'})
    else
      let ch = ch_open('unix:' . socket_path, {'mode': 'raw', 'timeout': 2000})
      if type(ch) == v:t_number && ch == 0
        call goime#_log('连接 goimed 失败')
        return
      endif
    endif
    let s:channel = ch
    let s:connected = 1
    call ch_setoptions(ch, {'callback': 'goime#_on_channel_data'})
    call goime#_log('已连接 goimed')

    call goime#_send_hello()
  catch /^Vim(let):E902:/
    " 连接被拒绝，socket 可能残留，启动 goimed
    call delete(socket_path)
    let binary = goime#_find_binary()
    if binary !=# ''
      call job_start([binary], {'out_cb': {_, data -> goime#_log(data)}})
      call goime#_log('正在启动 goimed...')
    endif
    let s:connected = 0
  catch
    call goime#_log('连接异常：' . v:exception)
    let s:connected = 0
  endtry
endfunction

" goime#disconnect 断开连接
function! goime#disconnect()
  if s:connected && type(s:channel) == v:t_channel
    call ch_close(s:channel)
  endif
  let s:channel = v:null
  let s:connected = 0
  call goime#_close_popup()
endfunction

" ============================================================================
" 协议通信
" ============================================================================

" goime#_send 发送 JSON Lines 消息
function! goime#_send(msg)
  if !s:connected || type(s:channel) != v:t_channel
    return
  endif
  let json = goime#_json_encode(a:msg)
  call ch_sendraw(s:channel, json . "\n")
endfunction

" goime#_send_hello 发送握手消息
function! goime#_send_hello()
  let schemes = get(g:, 'goime_schemes', [])
  let page_size = get(g:, 'goime_page_size', 0)
  let msg = {'method': 'hello', 'version': 1, 'client': g:goime_client_name}
  if page_size > 0
    let msg.page_size = page_size
  endif
  if !empty(schemes)
    let msg.schemes = schemes
  endif
  call goime#_send(msg)
endfunction

" goime#_send_input 发送按键输入
function! goime#_send_input(key)
  call goime#_send({'method': 'input', 'key': a:key})
endfunction

" goime#_send_enter 发送回车（上屏原始输入码）
function! goime#_send_enter()
  call goime#_send({'method': 'enter'})
endfunction

" goime#_send_escape 发送 Escape
function! goime#_send_escape()
  call goime#_send({'method': 'escape'})
endfunction

" goime#_send_backspace 发送退格
function! goime#_send_backspace()
  call goime#_send({'method': 'backspace'})
endfunction

" goime#_send_space 发送空格
function! goime#_send_space()
  call goime#_send({'method': 'space'})
endfunction

" goime#_send_select 选择候选项
function! goime#_send_select(index)
  call goime#_send({'method': 'select', 'index': a:index})
endfunction

" goime#_send_page 翻页
function! goime#_send_page(dir)
  call goime#_send({'method': 'page', 'dir': a:dir})
endfunction

" goime#_on_channel_data 接收通道数据回调
function! goime#_on_channel_data(ch, data)
  " 累积接收缓冲
  let s:buffer .= a:data

  " 按 \n 分割处理每一行
  while 1
    let nl = stridx(s:buffer, "\n")
    if nl < 0
      break
    endif
    let line = strpart(s:buffer, 0, nl)
    let s:buffer = strpart(s:buffer, nl + 1)
    if line ==# ''
      continue
    endif
    let resp = goime#_json_decode(line)
    if !empty(resp)
      call goime#_handle_response(resp)
    endif
  endwhile
endfunction

" ============================================================================
" 响应处理
" ============================================================================

" goime#_handle_response 处理服务端响应
function! goime#_handle_response(resp)
  let type = get(a:resp, 'type', '')
  if type ==# 'welcome'
    call s:handle_welcome(a:resp)
  elseif type ==# 'commit'
    call s:handle_commit(a:resp)
  elseif type ==# 'preedit'
    call s:handle_preedit(a:resp)
  elseif type ==# 'idle'
    call s:handle_idle()
  elseif type ==# 'error'
    call goime#_log('服务端错误：' . get(a:resp, 'message', ''))
  endif
endfunction

" s:handle_welcome 处理握手响应
function! s:handle_welcome(resp)
  let s:schemes = get(a:resp, 'schemes', [])
  let s:active_scheme = get(a:resp, 'active', '')
  let s:page_size = get(a:resp, 'page_size', 5)
  call goime#_log('握手成功，方案：' . s:active_scheme)
  call goime#_update_statusline()
endfunction

" s:handle_commit 处理上屏响应
function! s:handle_commit(resp)
  let s:preedit_text = ''
  let text = get(a:resp, 'text', '')
  if text !=# ''
    if mode() ==# 'i' || mode() ==# 'ic'
      let cur = getcurpos()
      let line = getline('.')
      let byte = cur[2] - 1
      call setline('.', strpart(line, 0, byte) . text . strpart(line, byte))
      call cursor(cur[1], cur[2] + strlen(text))
    endif
  endif
  call goime#_close_popup()

  " 处理 pending_key — 需要透传的后续字符
  let pending = get(a:resp, 'pending_key', '')
  if pending !=# ''
    call feedkeys(pending, 'n')
  endif
endfunction

" goime#_escape_feedkeys 转义 feedkeys 特殊字符
function! goime#_escape_feedkeys(text)
  " 转义 <, \, |, 等 feedkeys 特殊字符
  let escaped = substitute(a:text, '\\', '\\\\', 'g')
  let escaped = substitute(escaped, '<', '\\<lt>', 'g')
  let escaped = substitute(escaped, '|', '\\<Bar>', 'g')
  return escaped
endfunction

" s:handle_preedit 处理预编辑响应
function! s:handle_preedit(resp)
  let text = get(a:resp, 'text', '')
  let s:preedit_text = text
  let candidates = get(a:resp, 'candidates', {})
  call goime#_log('preedit text=[' . text . '] cand=' . (!empty(candidates) ? 'yes' : 'no'))
  if !empty(candidates)
    let list = get(candidates, 'list', [])
    call goime#_log('candidates count=' . len(list))
    let s:candidate_current_page = get(candidates, 'page', 0)
    let s:candidate_pages = get(candidates, 'total', 1)
    if !empty(list)
      call s:show_candidates(text, list)
      return
    endif
  endif
  if text ==# ''
    call goime#_close_popup()
  else
    call s:show_candidates(text, [])
  endif
endfunction

" s:handle_idle 处理空闲响应
function! s:handle_idle()
  let s:preedit_text = ''
  call goime#_close_popup()
endfunction

" ============================================================================
" 候选窗渲染
" ============================================================================

" s:show_candidates 显示候选词弹窗
" preedit_text: 当前输入码文本，显示在候选窗顶部
function! s:show_candidates(preedit_text, list)
  " 构建候选窗文本
  let lines = []

  " 第一行显示 preedit 文本（输入码）
  if a:preedit_text !=# ''
    call add(lines, a:preedit_text)
    call add(lines, '')
  endif

  for i in range(len(a:list))
    let item = a:list[i]
    let text = get(item, 'text', '')
    let code = get(item, 'code', '')
    let label = i + 1
    call add(lines, label . '. ' . text . '  ' . code)
  endfor

  " 翻页信息
  if s:candidate_pages > 1
    call add(lines, '— ' . (s:candidate_current_page + 1) . '/' . s:candidate_pages . '页 —')
  endif

  if empty(lines)
    call goime#_close_popup()
    return
  endif

  if has('popupwin')
    if s:popup_win > 0 && popup_getpos(s:popup_win) isnot v:null
      " 复用已有窗口，避免销毁重建
      call popup_settext(s:popup_win, lines)
    else
      call goime#_close_popup()
      let s:popup_win = popup_atcursor(lines, {
            \ 'padding': [0, 1, 0, 1],
            \ 'border': [],
            \ 'close': 'click',
            \ 'highlight': 'GoIMECandidate',
            \ })
    endif
    highlight default link GoIMECandidate Pmenu
  endif
endfunction

" goime#_close_popup 关闭候选窗
function! goime#_close_popup()
  if s:popup_win > 0
    try
      call popup_close(s:popup_win)
    catch
    endtry
    let s:popup_win = -1
  endif
endfunction

" ============================================================================
" 插入模式事件
" ============================================================================

" goime#on_insert_enter 进入插入模式时连接
function! goime#on_insert_enter()
  " 如果插件被禁用，不做任何事
  if !s:plugin_enabled
    return
  endif
  " 防重复：如果已经在插入模式（如从 InsertEnter 再触发）
  if s:prev_insert_mode
    return
  endif
  let s:prev_insert_mode = 1

  if !s:connected
    call goime#connect()
  endif

  " 如果不处于中文模式，直接返回
  if !s:chinese_mode
    return
  endif

  " 设置插入模式键映射（仅当处于中文模式时）
  call s:setup_insert_mappings()
endfunction

" goime#on_insert_leave 离开插入模式时清理
function! goime#on_insert_leave()
  let s:prev_insert_mode = 0
  let s:preedit_text = ''
  call goime#_close_popup()
  " 发送 escape 清空缓冲区
  if s:connected
    call goime#_send_escape()
  endif
  call s:restore_insert_mappings()
endfunction

" ============================================================================
" 插入模式映射管理
" ============================================================================

" s:insert_maps 保存的原始映射，用于恢复
let s:saved_maps = {}

" s:setup_insert_mappings 设置中文输入用的插入模式映射
function! s:setup_insert_mappings()
  if !s:chinese_mode
    return
  endif
  if get(g:, 'goime_no_default_mappings', 0)
    return
  endif

  " 字母键映射到 goime
  for c in split('abcdefghijklmnopqrstuvwxyz', '\zs')
    execute 'inoremap <silent> <expr> ' . c . ' goime#_on_char("' . c . '")'
  endfor

  " 数字键 1-0 选词（0=索引9）
  for i in range(1, 9)
    execute 'inoremap <silent> <expr> ' . i . ' goime#_on_number(''' . i . ''')'
  endfor
  " 0 键选第 10 个候选（索引 9）
  inoremap <silent> <expr> 0 goime#_on_number('10')

  " 翻页 + 特殊键（支持用户自定义映射）
  execute 'inoremap <silent> <expr> ' . g:goime_map_page_prev . ' goime#_on_comma()'
  execute 'inoremap <silent> <expr> ' . g:goime_map_page_next . ' goime#_on_period()'
  execute 'inoremap <silent> <expr> ' . g:goime_map_space . ' goime#_on_space()'
  execute 'inoremap <silent> <expr> ' . g:goime_map_backspace . ' goime#_on_backspace()'
  execute 'inoremap <silent> <expr> ' . g:goime_map_enter . ' goime#_on_enter()'
  execute 'inoremap <silent> <expr> ' . g:goime_map_escape . ' goime#_on_escape()'
  execute 'inoremap <silent> <expr> ' . g:goime_map_tab . ' goime#_on_tab()'
endfunction

" s:restore_insert_mappings 恢复插入模式映射
function! s:restore_insert_mappings()
  for c in split('abcdefghijklmnopqrstuvwxyz', '\zs')
    silent! execute 'iunmap ' . c
  endfor
  execute 'silent! iunmap ' . g:goime_map_space
  execute 'silent! iunmap ' . g:goime_map_backspace
  execute 'silent! iunmap ' . g:goime_map_enter
  execute 'silent! iunmap ' . g:goime_map_escape
  execute 'silent! iunmap ' . g:goime_map_tab
  " 数字键 1-0
  for i in range(1, 9)
    silent! execute 'iunmap ' . i
  endfor
  silent! iunmap 0
  " 翻页
  execute 'silent! iunmap ' . g:goime_map_page_prev
  execute 'silent! iunmap ' . g:goime_map_page_next
endfunction

" ============================================================================
" 按键处理
" ============================================================================

" goime#_on_char 处理字母字符输入
function! goime#_on_char(key)
  if !s:connected || !s:chinese_mode
    " 未连接或英文模式时直接返回该字符
    return a:key
  endif
  call goime#_send_input(a:key)
  return ''
endfunction

" goime#_on_space 处理空格
function! goime#_on_space()
  if !s:connected || !s:chinese_mode
    return "\<Space>"
  endif
  if s:preedit_text !=# ''
    call goime#_send_space()
    return ''
  endif
  return "\<Space>"
endfunction

" goime#_on_backspace 处理退格
function! goime#_on_backspace()
  if !s:connected || !s:chinese_mode
    return "\<BS>"
  endif
  if s:preedit_text !=# ''
    " 正在输入中文：发送退格到 goimed
    call goime#_send_backspace()
    return ''
  endif
  " 不在输入状态：执行 Vim 默认退格
  return "\<BS>"
endfunction

" goime#_on_enter 处理回车
function! goime#_on_enter()
  if !s:connected || !s:chinese_mode
    return "\<CR>"
  endif
  " 补全菜单打开时让给补全插件
  if pumvisible()
    return "\<CR>"
  endif
  if s:preedit_text !=# ''
    call goime#_send_enter()
    return ""
  endif
  return "\<CR>"
endfunction

" goime#_on_escape 处理 Escape
function! goime#_on_escape()
  if s:connected
    call goime#_send_escape()
  endif
  return "\<Esc>"
endfunction

" goime#_on_tab 处理 Tab（选第二个候选）
function! goime#_on_tab()
  if !s:connected || !s:chinese_mode || s:preedit_text ==# ''
    return "\<Tab>"
  endif
  " 补全菜单打开时让给补全插件
  if pumvisible()
    return "\<Tab>"
  endif
  call goime#_send_select(1)
  return ''
endfunction

" goime#_on_down 处理向下翻页
function! goime#_on_down()
  if !s:connected || !s:chinese_mode
    return "\<Down>"
  endif
  call goime#_send_page('next')
  return ''
endfunction

" goime#_on_up 处理向上翻页
function! goime#_on_up()
  if !s:connected || !s:chinese_mode
    return "\<Up>"
  endif
  call goime#_send_page('prev')
  return ''
endfunction

" goime#_on_pagedown 翻下一页
function! goime#_on_pagedown()
  if !s:connected || !s:chinese_mode
    return "\<PageDown>"
  endif
  call goime#_send_page('next')
  return ''
endfunction

" goime#_on_pageup 翻上一页
function! goime#_on_pageup()
  if !s:connected || !s:chinese_mode
    return "\<PageUp>"
  endif
  call goime#_send_page('prev')
  return ''
endfunction

" goime#_on_toggle 中英文切换（右 Shift 调用）
function! goime#toggle()
  let s:chinese_mode = !s:chinese_mode
  if s:chinese_mode
    call s:setup_insert_mappings()
  else
    call s:restore_insert_mappings()
  endif
  call goime#_close_popup()
  call goime#_send_escape()
  call goime#_update_statusline()
  " 显示切换提示
  if s:chinese_mode
    echohl Statement | echo 'GoIME: 中文模式' | echohl None
  else
    echohl Comment  | echo 'GoIME: 英文模式' | echohl None
  endif
endfunction

" ============================================================================
" 状态栏接口
" ============================================================================

" goime#status 返回状态栏显示文本
function! goime#status()
  if !s:connected || !s:plugin_enabled
    return g:goime_status_off
  endif
  if !s:chinese_mode
    return g:goime_status_en
  endif
  if g:goime_status_cn !=# '中'
    return g:goime_status_cn
  endif
  " 显示方案中文名
  let names = {'xiaohe': '小鹤双拼', 'fullpin': '全拼'}
  return get(names, s:active_scheme, s:active_scheme)
endfunction

" goime#status_echo 在命令行显示状态
function! goime#status_echo()
  if !s:connected
    echo 'GoIME: 未连接'
    return
  endif
  let mode = s:chinese_mode ? '中文' : '英文'
  let scheme = s:active_scheme !=# '' ? ' (' . s:active_scheme . ')' : ''
  echo 'GoIME: ' . mode . scheme
endfunction

" goime#_update_statusline 刷新状态栏
function! goime#_update_statusline()
  " 触发 redrawstatus
  if exists('*redrawstatus')
    redrawstatus!
  endif
endfunction

" ============================================================================
" 数字键选词（1-0）
" ============================================================================

" goime#_on_number 处理数字键选词
" 数字键 1-9 对应候选索引 0-8，0 对应索引 9
function! goime#_on_number(num)
  if !s:connected || !s:chinese_mode || s:preedit_text ==# ''
    return a:num
  endif
  let idx = a:num - 1
  if idx >= 0
    call goime#_send_select(idx)
  endif
  return ''
endfunction

" ============================================================================
" 逗号/句号翻页
" ============================================================================

" goime#_on_comma 处理逗号键（向上翻页）
function! goime#_on_comma()
  if !s:connected || !s:chinese_mode || s:preedit_text ==# ''
    return ','
  endif
  call goime#_send_page('prev')
  return ''
endfunction

" goime#_on_period 处理句号键（向下翻页）
function! goime#_on_period()
  if !s:connected || !s:chinese_mode || s:preedit_text ==# ''
    return '.'
  endif
  call goime#_send_page('next')
  return ''
endfunction

" ============================================================================
" 标点符号处理
" ============================================================================

" goime#_on_punct 处理标点符号
function! goime#_on_punct(char, fullwidth)
  if !s:connected || !s:chinese_mode
    return a:char
  endif
  if g:goime_ascii_punct
    return a:char
  endif
  return a:fullwidth
endfunction

" ============================================================================
" 插件启/禁用（<C-;> 调用）
" ============================================================================

let s:plugin_enabled = 1  " 1=启用，0=禁用

" goime#toggle_enabled 切换插件启用/禁用状态
function! goime#toggle_enabled()
  let s:plugin_enabled = !s:plugin_enabled
  if s:plugin_enabled
    call goime#_log('GoIME 已启用')
    if mode() ==# 'i' || mode() ==# 'ic'
      if !s:connected
        call goime#connect()
      endif
      if s:chinese_mode
        call s:setup_insert_mappings()
      endif
    endif
    echohl Statement | echo 'GoIME: 已启用' | echohl None
  else
    call goime#_log('GoIME 已禁用')
    call s:restore_insert_mappings()
    call goime#_close_popup()
    echohl Comment | echo 'GoIME: 已禁用' | echohl None
  endif
  call goime#_update_statusline()
endfunction

" ============================================================================
" 初始化
" ============================================================================

" 调试：输出内部状态
function! goime#_debug_dump()
  echom '=== GoIME Debug ==='
  echom 'connected=' . s:connected . ' chinese_mode=' . s:chinese_mode
  echom 'plugin_enabled=' . s:plugin_enabled
  echom 'preedit_text=' . s:preedit_text
  echom 'popup_win=' . s:popup_win
  echom 'channel_type=' . type(s:channel)
  echom 'buffer_size=' . strlen(s:buffer)
  echom 'candidate_pages=' . s:candidate_pages
  " 解析 buffer 内容
  if s:buffer !=# ''
    let lines = split(s:buffer, "\n")
    for line in lines
      if line !=# ''
        try
          let resp = json_decode(line)
          echom '  resp: type=' . resp.type
          echom '    text=' . get(resp, 'text', '')
          let cands = get(resp, 'candidates', {})
          if !empty(cands)
            echom '    candidates.list len=' . len(get(cands, 'list', []))
          else
            echom '    candidates: none'
          endif
        catch
          echom '  parse error: ' . line
        endtry
      endif
    endfor
  endif
  echom '=== End ==='
endfunction

" 循环切换输入方案（dir=1 下一个，dir=-1 上一个）
function! goime#cycle_scheme(dir)
  if empty(s:schemes)
    call goime#_log('无可用方案')
    return
  endif
  let idx = index(s:schemes, s:active_scheme)
  if idx < 0
    let idx = 0
  endif
  let idx = (idx + a:dir) % len(s:schemes)
  if idx < 0
    let idx = len(s:schemes) - 1
  endif
  call goime#set_scheme(s:schemes[idx])
endfunction

" 发送配置更新（分页大小、启用方案）
function! goime#send_config()
  let page_size = get(g:, 'goime_page_size', 5)
  if page_size <= 0
    let page_size = 5
  endif
  let schemes = get(g:, 'goime_schemes', [])
  let msg = {'method': 'config', 'page_size': page_size}
  if !empty(schemes)
    let msg.schemes = schemes
  endif
  call goime#_send(msg)
  call goime#_log('发送配置: page_size=' . page_size)
endfunction

" 切换输入方案
function! goime#set_scheme(name)
  call goime#_send({'method': 'set_scheme', 'name': a:name})
  let s:active_scheme = a:name
  call goime#_log('切换方案: ' . a:name)
  let s:preedit_text = ''
  call goime#_close_popup()
  call goime#_update_statusline()
endfunction

" 插件加载时自动初始化
call goime#_log('goime.vim 已加载')
