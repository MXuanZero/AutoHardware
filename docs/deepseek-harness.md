# deepseek-harness：本地构建与运行

所有配置 / 缓存都落在仓库内（默认会写到 `$HOME`），不修改任何全局配置；
`.gitignore` 已排除这些目录。`scripts/` 下提供两个脚本：

| 脚本 | 用途 |
| --- | --- |
| `scripts/dsh_start.fish` | **运行 dsh**（fish）：自动定位仓库根、切 Node 24、导出本地化环境变量、启动前完成插件与工作区配置，然后启动 |
| `scripts/env.sh` | 仅导出环境变量（bash）：需要在仓库内手动执行 pnpm 命令时 `source` 它 |

## 运行 dsh

```fish
scripts/dsh_start.fish                        # 默认 web，监听 127.0.0.1:3080 并开浏览器
scripts/dsh_start.fish web --no-open          # 不开浏览器
scripts/dsh_start.fish web --no-open --port 3099
scripts/dsh_start.fish tui                    # 终端 UI
scripts/dsh_start.fish headless "跑一下测试"   # 跑一个任务后退出
scripts/dsh_start.fish --help                 # 其余参数全部透传给 dsh
```

`dsh web` 是**前台常驻服务**，不会自己退出：看到 `dsh web: http://127.0.0.1:3080/?token=…`
就是在正常服务，用 Ctrl-C 结束。已配置好时启动约 2 秒；**首次**启动会先用 pnpm
把智能体团队插件装进 `web` profile（生成 `.dsh/profiles/web/pnpm-lock.yaml`），会多花几十秒。

## 启动前的自动配置

脚本中的这三步是幂等的，已配置则秒过：

| 步骤 | 行为 | 依据 |
| --- | --- | --- |
| 1 | 在 `web` profile 中启用**智能体团队**插件：`dsh plugin --profile web add packages/experimental/agent-team-profile`（用本地 `link:`，版本与源码一致） | 对应界面上的「智能体团队」开关 |
| 2 | 把仓库根目录登记为**默认工作区**（写入 `.dsh/storages/workspace.json`，并把 `createdAt` 设为当前时间，使 Web UI 启动时自动选中它） | Web UI 会恢复上次选择，否则 auto-pick 最近的工作区 |
| 3 | 以仓库根目录作为进程工作目录（会话的默认文件系统位置） | `deepseek-harness/docs/user/guide/index.zh.md` |

设置 `DSH_SKIP_SETUP=1` 可跳过第 1、2 步，比如只想临时换个 profile 试插件。

## 清理 / 重置本地状态

会话、工作区注册表、登录凭据都在 `.dsh/` 下（已被 git 忽略）：

```fish
# 只清会话与工作区（保留 profile 与登录，下次启动会重新登记本项目）
rm -rf .dsh/sessions .dsh/storages
scripts/dsh_start.fish web --no-open      # 重新生成干净的工作区

# 彻底重置（会丢失登录状态与已启用插件，需重跑 pnpm install 与插件启用）
rm -rf .dsh
```

注意：dsh 首次启动会在 `~/Documents/deepseek-harness/default-workspace` 自建一个占位
工作区。本脚本已提前登记项目工作区，因此不会再生成它；如过去生成过，可直接删除
`~/Documents/deepseek-harness`。

## 首次构建（bash）

```bash
source scripts/env.sh                        # 切 Node 24 + 本地化目录
cd deepseek-harness
corepack pnpm install                        # 首次安装依赖（按 package.json 锁定 pnpm@11.28.5）
corepack pnpm run build                      # 约 3 分钟，10 个 gate
```

`scripts/env.sh` / `scripts/dsh_start.fish` 把下列默认在主目录的位置改到仓库内：

| 变量 | 仓库内路径 | 默认位置 |
| --- | --- | --- |
| `DSH_HOME` | `.dsh/` | `~/.dsh` |
| `DSH_RESOURCE_CACHE` | `.cache/deepseek-harness/resources` | `~/.cache/deepseek-harness/resources` |
| `COREPACK_HOME` | `.pnpm/corepack` | `~/.cache/node/corepack` |
| `PNPM_HOME`（含 pnpm store） | `.pnpm/home` | `~/.local/share/pnpm` |
| `npm_config_cache` | `.pnpm/npm-cache` | `~/.npm` |
| `ELECTRON_CACHE` / `ELECTRON_BUILDER_CACHE` / `PLAYWRIGHT_BROWSERS_PATH` | `.cache/*` | `~/.cache/*` |

注意：`.dsh/` 内会写入 `.credentials.yaml` 等凭据，已在 `.gitignore` 中排除，请勿提交。
如需复用主目录里已有的登录状态，可执行 `cp -a ~/.dsh/. .dsh/`。
