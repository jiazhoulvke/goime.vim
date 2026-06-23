" goime.vim — GoIME 中文输入法 Vim 插件
" 请确保 goimed 守护进程已在 PATH 中
" 安装：Plug 'jiazhoulvke/goime.vim'

if exists('g:goime_loaded')
  finish
endif
let g:goime_loaded = 1

" ============================================================================
" 配置项（用户可通过 let g:goime_xxx = 'value' 覆盖默认值）
" ============================================================================

" GoIME socket 路径，空则自动推导：
"   优先 $XDG_RUNTIME_DIR/goime.sock
"   回退 /tmp/goime-$UID.sock
let g:goime_socket_path = get(g:, 'goime_socket_path', '')

" goimed 可执行文件路径，空则从 PATH 查找
let g:goime_binary = get(g:, 'goime_binary', '')
" TCP 主机地址（仅 TCP 模式有效，需同时设置 goime_port）
let g:goime_host = get(g:, 'goime_host', '127.0.0.1')

" TCP 端口（默认 11527，设为空则使用 Unix socket）
let g:goime_port = get(g:, 'goime_port', '11527')

" 中文模式状态栏显示文本
let g:goime_status_cn = get(g:, 'goime_status_cn', '中')

" 英文模式状态栏显示文本
let g:goime_status_en = get(g:, 'goime_status_en', 'EN')

" 未连接时状态栏显示文本（空=隐藏状态栏组件）
let g:goime_status_off = get(g:, 'goime_status_off', '')

" 中/英文切换键（默认 <S-Space>，右 Shift 等效；终端下无法区分左右 Shift）
let g:goime_toggle_key = get(g:, 'goime_toggle_key', '<S-Space>')

" 中/英标点模式（0=中文标点，1=英文标点，设为 1 无视 punct_map）
let g:goime_ascii_punct = get(g:, 'goime_ascii_punct', 0)

" 标点映射表（ASCII → 全角），用户可增删改
let g:goime_punct_map = get(g:, 'goime_punct_map', {
      \ ',': '，',
      \ '.': '。',
      \ ';': '；',
      \ ':': '：',
      \ '<': '《',
      \ '>': '》',
      \ '?': '？',
      \ '!': '！',
      \ '(': '（',
      \ ')': '）',
      \ '/': '、',
      \ '\': '、',
      \ '[': '【',
      \ ']': '】',
      \ "'": '‘',
      \ '"': '“',
      \ })

" 是否自动在插入模式连接 GoIME（1=自动，0=手动）
let g:goime_auto_connect = get(g:, 'goime_auto_connect', 0)

" 客户端标识
let g:goime_client_name = get(g:, 'goime_client_name', 'vim-goime-0.1')

" 期望的分页大小（0=使用服务端默认）
let g:goime_page_size = get(g:, 'goime_page_size', 5)

" 期望启用的输入方案列表（空=使用服务端全部）
let g:goime_schemes = get(g:, 'goime_schemes', [])

" 禁用所有默认按键映射
let g:goime_no_default_mappings = get(g:, 'goime_no_default_mappings', 0)

" Nerd Font 边框（1=启用，0=ASCII 字符）
let g:goime_nerdfont_border = get(g:, 'goime_nerdfont_border', 0)

" 自定义按键映射
if !exists('g:goime_map_toggle')
  let g:goime_map_toggle = '<S-Space>'
endif
if !exists('g:goime_map_page_prev')
  let g:goime_map_page_prev = ','
endif
if !exists('g:goime_map_page_next')
  let g:goime_map_page_next = '.'
endif
if !exists('g:goime_map_space')
  let g:goime_map_space = '<Space>'
endif
if !exists('g:goime_map_backspace')
  let g:goime_map_backspace = '<BS>'
endif
if !exists('g:goime_map_enter')
  let g:goime_map_enter = '<CR>'
endif
if !exists('g:goime_map_escape')
  let g:goime_map_escape = '<Esc>'
endif
if !exists('g:goime_map_tab')
  let g:goime_map_tab = '<Tab>'
endif
if !exists('g:goime_map_toggle_enable')
  let g:goime_map_toggle_enable = '<M-;>'
endif


" ============================================================================
" 命令
" ============================================================================

command! GoIMEToggle          call goime#toggle()
command! GoIMEStatus          call goime#status_echo()
command! GoIMEConnect         call goime#connect()
command! GoIMEEnable          call goime#enable()
command! GoIMEDisable         call goime#disable()
command! GoIMEDisconnect      call goime#disconnect()
command! GoIMEToggleEnabled   call goime#toggle_enabled()
command! -nargs=1 GoIMEScheme call goime#set_scheme(<q-args>)
command! GoIMEConfig call goime#send_config()
command! GoIMESchemeNext call goime#cycle_scheme(1)
command! GoIMESchemePrev call goime#cycle_scheme(-1)

" ============================================================================
" 映射
" ============================================================================

" 中/英文切换（默认 <S-Space>，右 Shift 等效）
execute 'inoremap <silent> ' . g:goime_toggle_key . ' <C-\><C-N>:call goime#toggle()<CR>a'
execute 'inoremap <silent> ' . g:goime_map_toggle_enable . ' <C-\><C-N>:call goime#toggle_enabled()<CR>a'

" 右 Shift → 中/英文切换（在能区分左右 Shift 的终端/GVim 下生效）
" 大多数终端无法区分左右 Shift，已通过 g:goime_toggle_key（默认 <S-Space>）提供等效功能

" ============================================================================
" 自动命令
" ============================================================================

augroup goime
  autocmd!
  " 进入插入模式时设置映射（始终注册，确保映射在每次进入插入模式时生效）
  " auto_connect 仅控制是否自动连接 goimed，不影响映射设置
  autocmd InsertEnter * call goime#on_insert_enter()
  " 离开插入模式时关闭候选窗
  autocmd InsertLeave * call goime#on_insert_leave()
  " 退出 Vim 时断开连接
  autocmd VimLeavePre * call goime#disconnect()
augroup END
