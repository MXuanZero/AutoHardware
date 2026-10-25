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
# 启动前自动完成（幂等，已配置则跳过）：
#   1. 在 web profile 中启用“智能体团队”插件
#      （@deepseek-ai/dsh-experimental-agent-team-profile，用本地 link: 安装，
#        版本与仓库源码一致，不依赖 npm 上的 latest 标签）
#   2. 把仓库根目录登记为 dsh 的默认工作区（Web UI 启动时自动选中）
#   3. 以仓库根目录作为进程工作目录（会话的默认文件系统位置）
#
# 其它行为：
#   * 自动定位仓库根目录（本脚本的上级目录），可在任意 cwd 调用
#   * 使用 Node 24（dsh 要求 node >= 24.9）
#   * DSH_HOME、资源缓存、pnpm/npm/corepack 缓存的默认位置（$HOME 下）
#     全部改为仓库内目录，避免污染主目录；不写任何全局配置
#   * 通过 exec 替换进程，Ctrl-C / 退出码行为与直接运行一致
#
# 环境变量开关：
#   DSH_SKIP_SETUP=1     跳过上面的自动配置（插件 / 工作区）

# ---- 定位仓库根目录 ----
set -l script_dir (cd (dirname (status --current-filename)); and pwd)
set -l root (realpath $script_dir/..)
set -l harness $root/deepseek-harness
set -l bin $harness/apps/cli/src/bin.ts
set -l tsx_loader $harness/node_modules/tsx/dist/esm/index.mjs

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
# 从仓库根目录启动时，让 tsx 仍使用 harness 的 tsconfig（paths 映射）
set -gx TSX_TSCONFIG_PATH $harness/tsconfig.json

mkdir -p $DSH_HOME $DSH_RESOURCE_CACHE

# ---- 依赖检查 ----
if not test -d $harness/node_modules
    echo "dsh_start: 依赖未安装，请先在 $harness 执行：corepack pnpm install" >&2
    exit 1
end
if not test -f $bin
    echo "dsh_start: 找不到 CLI 入口：$bin" >&2
    exit 1
end
if not test -f $tsx_loader
    echo "dsh_start: 找不到 tsx 加载器：$tsx_loader（请先 corepack pnpm install）" >&2
    exit 1
end
if not type -q jq
    echo "dsh_start: 需要 jq 来登记默认工作区（如已设置 DSH_SKIP_SETUP=1 可忽略）" >&2
end

# ---- 参数与 profile ----
set -l args $argv
if test (count $args) -eq 0
    set args web
end
set -l profile ''
set -l i 1
while test $i -le (count $args)
    set -l a $args[$i]
    switch $a
        case '--profile'
            set i (math $i + 1)
            test $i -le (count $args); and set profile $args[$i]
        case '--profile=*'
            set profile (string replace -- '--profile=' '' $a)
        case '--host' '--port' '--public-url' '--trusted-host' '--patch' '--tls-cert' '--tls-key' '--from-default-profile'
            # 这些启动器选项自带一个值，跳过它，避免被误当作 profile 名
            set i (math $i + 1)
        case '-*'
            # 其它开关：无值
        case '*'
            # 第一个位置参数即 profile 名（dsh [--profile] <name> [options] ...）
            if test -z "$profile"
                set profile $a
            end
    end
    set i (math $i + 1)
end
if test -z "$profile"
    set profile web
end

# ---- 智能体团队插件：未启用则用 CLI 启用 ----
function __dsh_enable_team_plugin --argument-names harness tsx_loader profile
    set -l bundle '@deepseek-ai/dsh-experimental-agent-team-profile'
    set -l pkg_path $harness/packages/experimental/agent-team-profile
    set -l manifest $DSH_HOME/profiles/$profile/package.json

    if test -f $manifest
        if node -e "const p=require(process.argv[1]);const b=(p.dsh&&p.dsh.profile&&p.dsh.profile.bundles)||[];process.exit(b.includes('$bundle')?0:1)" $manifest 2>/dev/null
            echo "dsh_start: 智能体团队插件已启用（profile: $profile）"
            return 0
        end
    end

    if not test -d $pkg_path
        echo "dsh_start: 找不到本地插件包 $pkg_path，跳过启用" >&2
        return 1
    end

    echo "dsh_start: 正在启用智能体团队插件（profile: $profile）…"
    pushd $harness >/dev/null; or return 1
    node --import $tsx_loader apps/cli/src/bin.ts plugin --profile $profile add $pkg_path
    set -l rc $status
    popd >/dev/null
    if test $rc -ne 0
        echo "dsh_start: 启用智能体团队插件失败（退出码 $rc），继续启动" >&2
    end
    return 0
end

# ---- 默认工作区：把仓库根目录登记进 workspace 注册表（幂等）----
function __dsh_seed_workspace --argument-names target
    set -l file $DSH_HOME/storages/workspace.json
    set -l root_path (realpath $target 2>/dev/null; or echo $target)
    set -l placeholder "$HOME/Documents/deepseek-harness/default-workspace"

    if not type -q jq
        return 1
    end

    set -l base '{}'
    if test -f $file
        set base (cat $file | string collect)
        if printf '%s' $base | jq -e --arg root $root_path 'any(.tables.workspaces[]?; .path == $root)' >/dev/null 2>&1
            echo "dsh_start: 默认工作区已登记 $root_path"
            return 0
        end
    end

    set -l now (date -u +%Y-%m-%dT%H:%M:%S.000Z)
    set -l id (uuidgen | string lower)
    set -l title (basename $root_path)
    set -l out (printf '%s' $base | jq --arg root $root_path --arg id $id \
        --arg title $title --arg now $now --arg ph $placeholder '
        . as $in
        | ($in.unit // {name: "workspace", version: 2}) as $unit
        | ($in.global // {}) as $g
        | ($in.tables.workspaces // {}) as $t0
        # 首次启动时 dsh 会自建 <Documents>/deepseek-harness/default-workspace；
        # 只要它还没有任何会话，就当作占位记录清掉，避免工作区列表里出现多余项。
        | ($t0 | with_entries(select((.value.path == $ph and ((.value.sessionIds // []) | length) == 0) | not))) as $t1
        | ([$t1[].path] | index($root)) as $existing
        | ($t1 + (if $existing == null
            then {($id): {path: $root, title: $title, sessionIds: [], createdAt: $now, updatedAt: $now}}
            else {} end)) as $t2
        | (if $existing == null then [$id] else [] end) as $prepend
        | ([$prepend[]] + [($g.workspaceIds // [])[]] | map(select($t2[.] != null)))
        | reduce .[] as $x ([]; if any(.[]; . == $x) then . else . + [$x] end) as $order
        | {
            unit: $unit,
            global: ($g
              + {initialized: true, workspaceIds: $order,
                 archivedSessionIds: ($g.archivedSessionIds // []),
                 pinnedSessionIds: ($g.pinnedSessionIds // [])}
              | (.defaultWorkspaceId // null) as $d
              | if $d == null or $t2[$d] != null then . else del(.defaultWorkspaceId) end),
            tables: {workspaces: $t2}
          }
        ' | string collect)
    set -l rc $pipestatus[1]
    if test $rc -ne 0
        echo "dsh_start: 登记默认工作区失败（jq 退出码 $rc）" >&2
        return 1
    end

    mkdir -p (dirname $file)
    printf '%s\n' $out >$file
    echo "dsh_start: 已把 $root_path 登记为默认工作区"
end

if not set -q DSH_SKIP_SETUP; or test "$DSH_SKIP_SETUP" = 0
    if test "$profile" = web
        __dsh_enable_team_plugin $harness $tsx_loader $profile
    end
    __dsh_seed_workspace $root
    echo "dsh_start: 工作目录 = $root"
end

# ---- 启动（工作目录 = 仓库根目录，即会话的默认文件系统位置）----
cd $root
exec node --import $tsx_loader $bin $args
