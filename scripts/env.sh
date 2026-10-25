# AutoHardware 本地环境脚本
#
#   source scripts/env.sh
#
# 作用：把 deepseek-harness（dsh）及 Node 工具链的配置、缓存、数据目录
# 全部落在本仓库目录内，而不是 $HOME。所有变量都只影响当前 shell，
# 不写入任何全局配置文件。

AUTOHARDWARE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# --- Node 24（deepseek-harness 要求 node >= 24.9）---
if [ -d "$HOME/.local/share/nvm/v24.21.0/bin" ]; then
  export PATH="$HOME/.local/share/nvm/v24.21.0/bin:$PATH"
fi

# --- DeepSeek Harness ---
# dsh 的家目录：默认 ~/.dsh，这里改到仓库内
export DSH_HOME="$AUTOHARDWARE_ROOT/.dsh"
# Python SDK / primary-runtime 的资源缓存：默认 ~/.cache/deepseek-harness/resources
export DSH_RESOURCE_CACHE="$AUTOHARDWARE_ROOT/.cache/deepseek-harness/resources"

# --- 包管理器（pnpm / npm / corepack）状态目录 ---
export COREPACK_HOME="$AUTOHARDWARE_ROOT/.pnpm/corepack"
export PNPM_HOME="$AUTOHARDWARE_ROOT/.pnpm/home"
# 注：pnpm 的 content-addressable store 会自动落在 $PNPM_HOME/store 下
export npm_config_cache="$AUTOHARDWARE_ROOT/.pnpm/npm-cache"
export npm_config_state_dir="$AUTOHARDWARE_ROOT/.pnpm/state"

# --- 可选：Electron / Playwright 之类工具的大体积缓存 ---
export ELECTRON_CACHE="$AUTOHARDWARE_ROOT/.cache/electron"
export ELECTRON_BUILDER_CACHE="$AUTOHARDWARE_ROOT/.cache/electron-builder"
export PLAYWRIGHT_BROWSERS_PATH="$AUTOHARDWARE_ROOT/.cache/playwright"

mkdir -p "$DSH_HOME" "$DSH_RESOURCE_CACHE"
