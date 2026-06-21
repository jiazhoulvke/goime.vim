#!/bin/sh
# 构建测试词库
GOIME_VIM_HOME="$(cd "$(dirname "$0")/.." && pwd)"
GOIME_DICT="${GOIME_VIM_HOME}/../go/goime/goime-dict"

mkdir -p "${GOIME_VIM_HOME}/tests/dict-cache"
"${GOIME_DICT}" build \
  "${GOIME_VIM_HOME}/tests/test.dict.txt" \
  "${GOIME_VIM_HOME}/tests/dict-cache/test.dict.txt.goime"
echo "done"
