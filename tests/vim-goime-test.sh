#!/bin/sh
# Vim + goime.vim 最小启动脚本（连接已有 goimed 服务）
# 用法：sh /tmp/vim-goime-test.sh [文件名]
#
# 依赖：goimed 需已在运行（用 ~/workspace/go/goime/goimed 启动）
#       默认连接 /run/user/1000/goime.sock
#
# 环境变量：
#   GOIME_SOCKET  - goimed socket 路径（默认 /run/user/1000/goime.sock）

GOIME_VIM_HOME="${HOME}/workspace/vim/goime.vim"
GOIME_SOCKET="${GOIME_SOCKET:-/run/user/1000/goime.sock}"

if [ ! -d "$GOIME_VIM_HOME" ]; then
  echo "错误：goime.vim 插件目录不存在：$GOIME_VIM_HOME"
  exit 1
fi

if [ ! -S "$GOIME_SOCKET" ]; then
  echo "错误：goimed socket 不存在：$GOIME_SOCKET"
  echo "请先在另一个终端启动 goimed："
  echo "  ${HOME}/workspace/go/goime/goimed"
  exit 1
fi

# 创建 vimrc
VIMRC=$(mktemp /tmp/goime-vimrc-XXXXXX.vim)
cat > "$VIMRC" <<VIMRC
" ============================================================
" GoIME 测试用 vimrc —— 连接已有 goimed
" ============================================================

set nocompatible

" 将 goime.vim 加入运行时路径
execute 'set rtp+=' . fnameescape('${GOIME_VIM_HOME}')

" GoIME 配置 —— 连接已有的 goimed
let g:goime_debug = 1
let g:goime_socket_path = '${GOIME_SOCKET}'
let g:goime_page_size = 10
let g:goime_auto_connect = 1

" 状态栏显示 goime 状态
set laststatus=2
set statusline=
set statusline+=%{goime#status()}
set statusline+=\ %f
set statusline+=%=

echom 'GoIME test: goime.vim loaded from ${GOIME_VIM_HOME}'
echom 'GoIME socket: ${GOIME_SOCKET}'
VIMRC

echo "=== GoIME Vim 测试环境 ==="
echo "插件路径: ${GOIME_VIM_HOME}"
echo "socket:    ${GOIME_SOCKET}"
echo "vimrc:     ${VIMRC}"
echo ""
echo "可用命令：:GoIMEConnect / :GoIMEToggle / :GoIMEStatus / :GoIMEToggleEnabled"
echo "按键：<S-Space> 中英切换, <M-;> 启用/禁用, ,/. 翻页, 1-0 选词"
echo ""

exec vim -u "${VIMRC}" "${@}"
