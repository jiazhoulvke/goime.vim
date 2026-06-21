# goime.vim

GoIME 的 Vim 8+ 客户端。通过 Unix Socket 与 goimed 通信，直接输入中文。

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
let g:goime_socket_path = ''    " Socket 路径（空=自动）
let g:goime_page_size = 5       " 每页候选数
let g:goime_schemes = []        " 启用方案列表
let g:goime_auto_connect = 1    " 自动连接
let g:goime_debug = 0           " 调试日志
```

## 命令

| 命令 | 说明 |
|------|------|
| `:GoIMEConnect` | 连接 |
| `:GoIMEToggle` | 中/英切换 |
| `:GoIMEStatus` | 状态 |
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
| `<Tab>` | 临时英文模式 | `g:goime_map_tab` |
| `,` | 上一页 | `g:goime_map_page_prev` |
| `.` | 下一页 | `g:goime_map_page_next` |

始终有效的全局映射（不受 `g:goime_no_default_mappings` 影响）：

| 键 | 功能 |
|---|---|
| `<S-Space>` | 中/英文切换 |
| `<C-;>` | 启用/禁用插件 |

### 自定义映射键

```vim
" 默认值
let g:goime_map_toggle = '<S-Space>'        " 中/英文切换
let g:goime_map_page_prev = ','              " 上一页
let g:goime_map_page_next = '.'              " 下一页
let g:goime_map_space = '<Space>'            " 选首选
let g:goime_map_backspace = '<BS>'           " 回删拼音
let g:goime_map_enter = '<CR>'               " 上屏
let g:goime_map_escape = '<Esc>'             " 清空拼音
let g:goime_map_tab = '<Tab>'               " 临时英文
let g:goime_map_toggle_enable = '<C-;>'      " 启用/禁用插件

" 例如改为 [ 和 ] 翻页
let g:goime_map_page_prev = '['
let g:goime_map_page_next = ']'
```

### 禁用所有默认映射

```vim
let g:goime_no_default_mappings = 1
```

设置后，除 `<S-Space>`（中/英切换）和 `<C-;>`（启/禁用）外，所有插入模式映射都不会自动创建，你可通过自定义变量或 `inoremap` 手动配置。

## 状态栏

goime.vim 提供 `goime#status()` 函数，可在状态栏显示当前输入法状态（中文/英文/未连接）。

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

许可证 GPLv3
