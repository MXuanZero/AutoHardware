#!/usr/bin/env fish
#
# dsh_start.fish — 在仓库内启动 DeepSeek Harness（dsh）
#
# 用法：
#   scripts/dsh_start.fish                       # 等价于 dsh web（默认）
#   scripts/dsh_start.fish web --no-open --port 3099
#   scripts/dsh_start.fish tui
#   scripts/dsh_start.fish headless "跑一下测试"
#   scripts/dsh_start.fish --help                # 透传给 dsh
#
# 行为：
#   * 自动定位仓库根目录（本脚本的上级目录），可在任意 cwd 调用
#   * 使用 Node 24（dsh 要求 node >= 24.9）
#   * DSH_HOME、资源缓存、pnpm/npm/corepack 缓存的默认位置（$HOME 下）
#     全部改为仓库内目录，避免污染主目录；不写任何全局配置
#   * 通过 exec 替换进程，Ctrl-C / 退出码行为与直接运行一致

# ---- 定位仓库根目录 ----
set -l script_dir (cd (dirname (status --current-filename)); and pwd)
set -l root (realpath $script_dir/..)

# ---- Node 24（若已满足版本要求则沿用当前 PATH 中的 node）----
set -l nvm_bin $HOME/.local/share/nvm/v24.21.0/bin
set -l need_switch 0
if not type -q node
    set need_switch 1
else
    set -l major (node -p 'process.versions.node.split(".")[0]' 2>/dev/null)
    set -l minor (node -p 'process.versions.node.split(".")[1]' 2>/dev/null)
    if test -z "$major"; or test "$major" -lt 24; or begin; test "$major" -eq 24; and test "$minor" -lt 9; end
        set need_switch 1
    end
end
if test $need_switch -eq 1
    if test -x $nvm_bin/node
        set -gx PATH $nvm_bin $PATH
    else
        echo "dsh_start: 需要 Node.js >= 24.9（当前: "(node -v 2>/dev/null; or echo 未安装) "）" >&2
        echo "dsh_start: 未找到备用 Node: $nvm_bin" >&2
        exit 1
    end
end

# ---- 目录本地化 ----
set -gx DSH_HOME $root/.dsh
set -gx DSH_RESOURCE_CACHE $root/.cache/deepseek-harness/resources
set -gx COREPACK_HOME $root/.pnpm/corepack
set -gx PNPM_HOME $root/.pnpm/home
set -gx npm_config_cache $root/.pnpm/npm-cache
set -gx npm_config_state_dir $root/.pnpm/state
set -gx ELECTRON_CACHE $root/.cache/electron
set -gx ELECTRON_BUILDER_CACHE $root/.cache/electron-builder
set -gx PLAYWRIGHT_BROWSERS_PATH $root/.cache/playwright

mkdir -p $DSH_HOME $DSH_RESOURCE_CACHE

# ---- 依赖与产物检查 ----
set -l harness $root/deepseek-harness
if not test -d $harness/node_modules
    echo "dsh_start: 依赖未安装，请先在 $harness 执行：corepack pnpm install" >&2
    exit 1
end
if not test -f $harness/apps/cli/src/bin.ts
    echo "dsh_start: 找不到 CLI 入口 $harness/apps/cli/src/bin.ts" >&2
    exit 1
end

# ---- 组装参数（无参数时默认 web）----
set -l args $argv
if test (count $args) -eq 0
    set args web
end

# ---- 启动 ----
cd $harness
exec node --import tsx/esm apps/cli/src/bin.ts $args
