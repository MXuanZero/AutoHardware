# AutoHardware

自动化硬件设计相关工具与实验。

## 子模块（submodules）

| 路径 | 上游仓库 | 跟踪分支 |
| --- | --- | --- |
| `third_party/kicad` | https://gitlab.com/kicad/code/kicad.git | `master` |
| `third_party/kicad-python` | https://gitlab.com/kicad/code/kicad-python.git | `main` |
| `third_party/deepseek-harness` | https://github.com/deepseek-ai/deepseek-harness.git | `master` |

子模块均以浅克隆（`--depth 1`）方式添加，并在 `.gitmodules` 中设置了 `shallow = true`，
因此首次拉取和后续 `submodule update` 都不会下载完整历史，可显著节省磁盘与带宽。

### 克隆本仓库（含子模块）

```bash
git clone --recurse-submodules --shallow-submodules <本仓库地址>
```

### 已有仓库初始化 / 更新子模块

```bash
git submodule update --init --recursive      # 首次初始化
git submodule update --remote --recursive    # 拉取各子模块跟踪分支的最新提交
```

### 常用维护命令

```bash
git submodule status                         # 查看当前锁定提交
cd third_party/kicad && git checkout <sha>   # 手动切换子模块版本
git add third_party/kicad && git commit      # 记录新的子模块提交
```
