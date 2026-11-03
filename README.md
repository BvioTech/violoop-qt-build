# violoop-qt-build

构建 violoop 自己的 Qt 6.8.5 包：全部模块按 `v6.8.5-lts-lgpl` 对齐，
`qtbase` 固定用 GLES2 后端（`-opengl es2`），`qtquicktimeline` 用
BvioTech 自己 fork 的、带一个上游 keyframe bug 修复的版本。

## 模块来源

| 模块 | 来源 | ref |
| --- | --- | --- |
| qtbase | `qt/qtbase` 官方 | `v6.8.5-lts-lgpl` |
| qtshadertools | `qt/qtshadertools` 官方 | `v6.8.5-lts-lgpl` |
| qtdeclarative | `qt/qtdeclarative` 官方 | `v6.8.5-lts-lgpl` |
| qtwayland | `qt/qtwayland` 官方 | `v6.8.5-lts-lgpl` |
| **qtquicktimeline** | **`BvioTech/qtquicktimeline`（fork）** | **`v6.8.5-violoop1`** |
| qtquick3d | `qt/qtquick3d` 官方 | `v6.8.5-lts-lgpl` |

只有 `qtquicktimeline` 是 fork，其余 5 个直接引用官方 tag。注意官方 tag
的真实名字是 `v6.8.5-lts-lgpl`，不是裸的 `v6.8.5`——改版本号时先用
`git ls-remote --tags <repo-url>` 确认实际标签名。

`v6.8.5-violoop1` 上的补丁是上游 Qt 已有、但还没 cherry-pick 进
`qtquicktimeline` 6.8 LTS 镜像的两个 commit（`QTBUG-142669`，均标
`Pick-to: 6.10 6.8`），修复 `QQuickKeyframeGroupPrivate::loadKeyframes()`
的一个 off-by-one：每个通道会丢最后一个关键帧，单关键帧通道整个变空。

`qtbase` 用 `-opengl es2` 而不是让 `configure` 自动探测，是因为自动探测
在装了桌面 Mesa 开发包的机器上会选中桌面 OpenGL/GLVND 而不是 GLES2，
导致运行时在目标设备上拿不到正确的 GL 版本协商结果。

所有具体参数见 `modules.conf`。

## 构建

构建机器是 **arm64 原生**（GitHub Actions 的 `ubuntu-24.04-arm` 机型，见
`.github/workflows/build.yml`），不是交叉编译，不需要额外的工具链/
sysroot——`configure`/`qt-configure-module` 用构建机自己的编译器和系统
头文件/库（`libgles2-mesa-dev`/`libegl1-mesa-dev` 等）。

```bash
export QT_PREFIX=/opt/violoop-qt6   # 默认值，独立于系统 qt6-*
./build-all.sh                      # fetch + build + package 一次跑完
```

也可以分步跑：`scripts/fetch.sh`、`scripts/build.sh`、
`scripts/package-deb.sh`，每一步都是增量/可重复执行的。

构建顺序（即 `modules.conf` 文件里的顺序）：
`qtbase` → `qtshadertools` → `qtdeclarative` → `qtwayland`/
`qtquicktimeline` → `qtquick3d`。

CI 在 `workflow_dispatch` 或推 `v*` tag 时触发，产出的 `.deb` 作为 action
artifact 上传。`src/`、`build/` 两个目录按 `modules.conf`/`scripts/` 的
内容做了缓存，重跑调试同一个 ref 不用每次都从头拉源码、从头编译。

推 `v*` tag 触发的构建额外会把 `.deb` 发布到这个仓库的 GitHub Release
（tag 名去掉前缀 `v` 就是 `.deb` 的包版本号，例如推 `v6.8.5-violoop1`
会产出 `violoop-qt6_6.8.5-violoop1_arm64.deb`）；重新跑同一个 tag 会更新
已有 release 的附件，不会报错。`workflow_dispatch` 手动触发不会创建
release，只产出 artifact，方便调试构建本身。

这个仓库目前只发布到自己的 GitHub Release，不包含发布到私有 APT 仓库的
步骤。

## License

本仓库自己的内容（构建脚本、`modules.conf`、CI 配置、文档）以
**GPL-3.0-or-later** 开源，见 `LICENSE`。

这**不**改变构建产出物（`dist/*.deb`）里打包的 Qt 本身的授权——Qt 各模块
沿用各自上游的授权（主要是 LGPL-3.0，部分 GPL-3.0/商业双授权，见各模块
源码自带的 `LICENSES/`），这些源码只在构建时拉取到 `.gitignore` 掉的
`src/` 目录，不会被提交进这个仓库。`qtquicktimeline` 的 fork
（`BvioTech/qtquicktimeline`）本身也保留了它原来的 Qt 授权，不受这个仓库
License 的影响。
