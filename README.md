# violoop-qt-build

我们自己的 Qt 6.8.5 构建：固定用 `-opengl es2`（而不是让 `configure` 自动
探测成桌面 OpenGL/GLVND——那是 `edge-front3` 蒙皮动画踩过的真实坑，细节
见 `edge-front3/qt3d-spike/docs/plan-patch-qt-source.md`），外加
`qtquicktimeline` 的一个真实 Qt bug 修复（`QTBUG-142669`，off-by-one 导致
最后一个关键帧被丢、单关键帧通道整个变空）。

## 模块来源

6 个模块里只有 `qtquicktimeline` 是我们自己 fork 的，其余 5 个直接引用
官方 tag，不单独 fork（取舍见 `edge-front3` 那份计划文档的"决定"一节）：

| 模块 | 来源 | ref |
| --- | --- | --- |
| qtbase | `qt/qtbase` 官方 | `v6.8.5-lts-lgpl` |
| qtshadertools | `qt/qtshadertools` 官方 | `v6.8.5-lts-lgpl` |
| qtdeclarative | `qt/qtdeclarative` 官方 | `v6.8.5-lts-lgpl` |
| qtwayland | `qt/qtwayland` 官方 | `v6.8.5-lts-lgpl` |
| **qtquicktimeline** | **`BvioTech/qtquicktimeline`（我们的 fork）** | **`v6.8.5-violoop1`** |
| qtquick3d | `qt/qtquick3d` 官方 | `v6.8.5-lts-lgpl` |

注意官方 tag 的真实名字是 `v6.8.5-lts-lgpl`，不是裸的 `v6.8.5`——改版本号
时先用 `git ls-remote --tags <repo-url>` 确认一下实际标签名。

`v6.8.5-violoop1` 上的补丁是从上游 Qt 的两个已存在、但还没被 cherry-pick
进 `qtquicktimeline` 6.8 LTS 镜像的 commit（`QTBUG-142669`，都标了
`Pick-to: 6.10 6.8`）搬过来的，不是我们自己手写的修复，细节见那两个
commit 本身的 message。

所有具体参数见 `modules.conf`。

## 用法

```bash
export QT_PREFIX=/opt/violoop-qt6   # 默认就是这个，独立于系统 qt6-*
./build-all.sh                      # fetch + build + package 一次跑完
```

也可以分步跑：`scripts/fetch.sh`、`scripts/build.sh`、
`scripts/package-deb.sh`（每一步都是增量/可重复执行的）。

构建顺序（`modules.conf` 文件里的顺序即构建顺序）：
`qtbase` → `qtshadertools` → `qtdeclarative` → `qtwayland`/
`qtquicktimeline` → `qtquick3d`。

## 还没做的事

- 发布到哪个私有 APT 仓库——留给下一步单独讨论，这个仓库目前只产出
  `.deb` 文件到 `dist/`。
- CI（GitHub Actions 自动触发构建）——独立任务，不阻塞先把脚本手动跑通。
- 把其余 5 个模块也镶一份到 `BvioTech` 下（更保守的 GPL 合规方案）——
  已经决定先不做。
