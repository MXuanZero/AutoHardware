# 子模块（submodules）

| 路径 | 上游仓库 | 跟踪分支 | 浅克隆体积 |
| --- | --- | --- | --- |
| `kicad/` | https://gitlab.com/kicad/code/kicad.git | `master` | ≈1.3G |
| `kicad-python/` | https://gitlab.com/kicad/code/kicad-python.git | `main` | ≈1.3M |
| `deepseek-harness/` | https://github.com/deepseek-ai/deepseek-harness.git | `master` | ≈185M |

三个子模块均以浅克隆（`--depth 1`）方式添加，并在 `.gitmodules` 中设置了 `shallow = true`，
因此首次拉取和后续 `submodule update` 都不会下载完整历史，可显著节省磁盘与带宽。

> `kicad-python` 自身带有一个指向 KiCad 源码的嵌套子模块（`kicad-python/kicad`），
> 因根目录已有 `kicad/`，此处保持**未初始化**（可省约 1.3G 空间）。因此顶层
> `git status` 会显示 `modified: kicad-python (modified content)`，属预期现象，
> 需要用时可执行 `git -C kicad-python submodule update --init`。

## 克隆本仓库（含子模块）

```bash
git clone --recurse-submodules --shallow-submodules <本仓库地址>
```

## 已有仓库初始化 / 更新子模块

```bash
git submodule update --init                  # 首次初始化（kicad-python 的嵌套 kicad 建议跳过）
git submodule update --remote --recursive    # 拉取各子模块跟踪分支的最新提交
```

## 常用维护命令

```bash
git submodule status                         # 查看当前锁定提交
cd kicad && git checkout <sha>               # 手动切换子模块版本
git add kicad && git commit                  # 记录新的子模块提交
```
