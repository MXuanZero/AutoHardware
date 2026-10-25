# AutoHardware

自动化硬件设计相关工具与实验。

## 子模块（submodules）

| 路径 | 上游仓库 | 跟踪分支 |
| --- | --- | --- |
| `kicad/` | https://gitlab.com/kicad/code/kicad.git | `master` |
| `kicad-python/` | https://gitlab.com/kicad/code/kicad-python.git | `main` |
| `deepseek-harness/` | https://github.com/deepseek-ai/deepseek-harness.git | `master` |

子模块均以浅克隆（`--depth 1`）方式添加，并在 `.gitmodules` 中设置了 `shallow = true`，
因此首次拉取和后续 `submodule update` 都不会下载完整历史，可显著节省磁盘与带宽。

> `kicad-python` 自身带有一个指向 KiCad 源码的嵌套子模块（`kicad-python/kicad`），
> 因根目录已有 `kicad/`，此处保持**未初始化**（可省约 1.3G 空间）。因此顶层
> `git status` 会显示 `modified: kicad-python (modified content)`，属预期现象，
> 需要用时可执行 `git -C kicad-python submodule update --init`。

### 克隆本仓库（含子模块）

```bash
git clone --recurse-submodules --shallow-submodules <本仓库地址>
```

### 已有仓库初始化 / 更新子模块

```bash
git submodule update --init                  # 首次初始化（kicad-python 的嵌套 kicad 建议跳过）
git submodule update --remote --recursive    # 拉取各子模块跟踪分支的最新提交
```

### 常用维护命令

```bash
git submodule status                         # 查看当前锁定提交
cd kicad && git checkout <sha>               # 手动切换子模块版本
git add kicad && git commit                  # 记录新的子模块提交
```

## deepseek-harness 本地构建与运行

所有配置 / 缓存都落在仓库内（默认会写到 `$HOME`），不修改任何全局配置；
`.gitignore` 已排除这些目录。`scripts/` 下提供两个脚本：

| 脚本 | 用途 |
| --- | --- |
| `scripts/dsh_start.fish` | **运行 dsh**（fish）：自动定位仓库根、切 Node 24、导出本地化环境变量并启动 |
| `scripts/env.sh` | 仅导出环境变量（bash）：需要在仓库内手动执行 pnpm 命令时 `source` 它 |

### 运行 dsh

```fish
scripts/dsh_start.fish                        # 默认 web，监听 127.0.0.1:3080 并开浏览器
scripts/dsh_start.fish web --no-open          # 不开浏览器
scripts/dsh_start.fish web --no-open --port 3099
scripts/dsh_start.fish tui                    # 终端 UI
scripts/dsh_start.fish headless "跑一下测试"   # 跑一个任务后退出
scripts/dsh_start.fish --help                 # 其余参数全部透传给 dsh
```

### 首次构建（bash）

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

注意：`.dsh/` 内会写入 `/.credentials.yaml` 等凭据，已在 `.gitignore` 中排除，请勿提交。
如需复用主目录里已有的登录状态，可执行 `cp -a ~/.dsh/. .dsh/`。
