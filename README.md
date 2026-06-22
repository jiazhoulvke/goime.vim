# goime.vim

GoIME 的 Vim 8+ 客户端。通过 Unix Socket（或 TCP）与 goimed 通信，直接输入中文。

## 安装

需要 [goimed](https://github.com/jiazhoulvke/goime) 守护进程。

### vim-plug

```vim
Plug 'jiazhoulvke/goime.vim'
```

### 手动

```vim
set rtp+=~/workspace/vim/goime.vim
```

## 配置

```vim
" 是否默认启用插件（0=禁用，1=启用）。按 <C-;> 或 :GoIMEToggleEnabled 启用
let g:goime_enabled = 0

" Socket 路径（空=自动推导，设置端口号后自动切换到 TCP 模式）
let g:goime_socket_path = ''

" goimed 可执行文件路径（空=从 PATH 查找）
let g:goime_binary = ''

" TCP 连接地址（仅端口号非空时生效）
let g:goime_host = '127.0.0.1'

" TCP 端口（空=使用 Unix Socket，设值后自动切换到 TCP 模式）
let g:goime_port = ''

" 每页候选数
let g:goime_page_size = 5

" 启用方案列表（空=服务端全部方案）
let g:goime_schemes = []

" 自动连接（1=进入插入模式自动连接，0=手动）
let g:goime_auto_connect = 0

" 中/英标点模式（1=中文标点，0=英文标点）
let g:goime_ascii_punct = 1

" 客户端标识
let g:goime_client_name = 'vim-goime-0.1'

" 中/英文切换键
let g:goime_toggle_key = '<S-Space>'

" 调试日志
let g:goime_debug = 0
```

## 命令

| 命令 | 说明 |
|------|------|
| `:GoIMEConnect` | 连接 |
| `:GoIMEDisconnect` | 断开连接 |
| `:GoIMEToggle` | 中/英切换 |
| `:GoIMEToggleEnabled` | 切换插件启用/禁用 |
| `:GoIMEStatus` | 状态 |
| `:GoIMEConfig` | 向服务端发送配置更新 |
| `:GoIMEScheme <name>` | 切换方案 |
| `:GoIMESchemeNext` | 下一个方案 |
| `:GoIMESchemePrev` | 上一个方案 |

## 按键

### 默认映射

中文模式下自动设置以下插入模式映射：

| 键 | 功能 | 可自定义变量 |
|---|---|---|
| `a-z` | 输入拼音 | — |
| `1-9` | 选第 1-9 个候选 | — |
| `0` | 选第 10 个候选 | — |
| `<Space>` | 选首选词 | `g:goime_map_space` |
| `<BS>` | 回删拼音 | `g:goime_map_backspace` |
| `<CR>` | 上屏当前拼音 | `g:goime_map_enter` |
| `<Esc>` | 清空拼音 | `g:goime_map_escape` |
| `<Tab>` | 选第二个候选 | `g:goime_map_tab` |
| `,` | 上一页 | `g:goime_map_page_prev` |
| `.` | 下一页 | `g:goime_map_page_next` |

始终有效的全局映射（不受 `g:goime_no_default_mappings` 影响）：

| 键 | 功能 | 可自定义变量 |
|---|---|---|
| `<S-Space>` | 中/英文切换 | `g:goime_toggle_key` |
| `<C-;>` | 启用/禁用插件 | `g:goime_map_toggle_enable` |

### 自定义映射键

```vim
" 默认值
let g:goime_toggle_key = '<S-Space>'             " 中/英文切换（注意：全局配置，非映射变量）
let g:goime_map_toggle = '<S-Space>'              " 中/英文切换（已废弃，请使用 g:goime_toggle_key）
let g:goime_map_page_prev = ','                    " 上一页
let g:goime_map_page_next = '.'                    " 下一页
let g:goime_map_space = '<Space>'                  " 选首选
let g:goime_map_backspace = '<BS>'                 " 回删拼音
let g:goime_map_enter = '<CR>'                     " 上屏
let g:goime_map_escape = '<Esc>'                   " 清空拼音
let g:goime_map_tab = '<Tab>'                     " 选第二个候选
let g:goime_map_toggle_enable = '<C-;>'            " 启用/禁用插件

" 例如改为 [ 和 ] 翻页
let g:goime_map_page_prev = '['
let g:goime_map_page_next = ']'
```

### 方向键翻页

以下函数已实现但未默认绑定，手动映射即可启用方向键翻页：

```vim
inoremap <Down> <C-\><C-O>:call goime#_on_down()<CR>
inoremap <Up> <C-\><C-O>:call goime#_on_up()<CR>
inoremap <PageDown> <C-\><C-O>:call goime#_on_pagedown()<CR>
inoremap <PageUp> <C-\><C-O>:call goime#_on_pageup()<CR>
```

### 禁用所有默认映射

```vim
let g:goime_no_default_mappings = 1
```

设置后，除 `<S-Space>`（中/英切换）和 `<C-;>`（启/禁用）外，所有插入模式映射都不会自动创建，你可通过自定义变量或 `inoremap` 手动配置。

## 候选窗

goime.vim 使用 Vim 弹出窗口（popup window）显示候选词。窗口样式：
- 圆角边框
- 第一行显示正在输入的拼音（preedit）
- 候选词编号显示，如 `1. 你 [ni3]`
- 多页时显示 `— 1/3页 —`

## 状态栏

goime.vim 提供 `goime#status()` 函数，可在状态栏显示当前输入法状态（中文/英文/未连接/插件禁用）。

### 显示逻辑

| 状态 | 显示内容 |
|------|----------|
| 未连接 | `g:goime_status_off`（默认空=隐藏） |
| 插件禁用 | 空字符串（隐藏） |
| 英文模式 | `g:goime_status_en`（默认 `EN`） |
| 中文模式（`g:goime_status_cn` 默认 `'中'`） | 方案中文名（如 `小鹤双拼`） |
| 中文模式（`g:goime_status_cn` 自定义） | 显示 `g:goime_status_cn` 的值 |

### 基础用法

```vim
" 直接加到 statusline
set statusline+=%{goime#status()}

" 或覆盖整个 statusline
set statusline=%f\ %m\ %=%{goime#status()}
```

### 自定义显示文本

```vim
let g:goime_status_cn = '中'     " 中文模式（默认显示方案名，如'小鹤双拼'）
let g:goime_status_en = 'EN'     " 英文模式
let g:goime_status_off = ''      " 未连接（空=隐藏组件）
```

### airline

自动集成，无需配置。

### lightline

```vim
let g:lightline = {
      \ 'active': {
      \   'left': [
      \     ['mode', 'paste', 'goime'],
      \     ['readonly', 'filename', 'modified']
      \   ]
      \ },
      \ 'component': {
      \   'goime': '%{goime#status()}'
      \ }
      \ }
```

## 自动启动

插件检测到 socket 不存在且 `goimed` 可在 PATH 中找到时，会自动异步启动 `goimed` 守护进程并等待 socket 就绪（最长 1 秒）。

如果 socket 连接被拒绝（残留 socket 文件），插件会删除残留文件，重新启动 `goimed` 并重试（最长 2 秒）。

## 协议特性

**pending_key 转发**：commit 响应可包含 `pending_key` 字段，插件通过 `feedkeys()` 将按键转发给 Vim，用于需要透传后续字符的场景。

## 调试

```vim
:echo goime#_debug_dump()
```

输出内部状态（连接状态、预编辑文本、缓冲区内容等）到消息历史。

## TCP 支持

goime.vim 支持 TCP 连接。配置 `g:goime_port` 即可自动切换到 TCP 模式：

```vim
let g:goime_port = 11527
" 可自定义主机地址（默认 127.0.0.1）
let g:goime_host = '127.0.0.1'
```

### TCP 自动发现链

当未指定端口时，插件按以下顺序尝试发现 goimed：
1. 直接连接 `g:goime_host:g:goime_port`
2. 读取端口文件 `~/.cache/goime/goime.port`
3. 自动启动 `goimed --listen tcp --host <host> --port <port>`
4. 每 500ms 重试，最长 6 秒

许可证 GPLv3
