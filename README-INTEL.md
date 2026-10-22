# DogSC Intel / Ventura 兼容分支

基于 laogou717/dogsc 的 v0.1.8（567fd6ed3bf113227dcf3e815f87ce60f0b69497）。
源码继续遵循原 MIT License；随附字体保留原许可。

目标设备：MacBook Pro 13-inch 2017 / Intel i5 / Iris Plus 640 / 8GB / macOS 13.7.4。
部署目标：Intel x86_64、macOS 13.0 及以上。

**当前修复：内部构建 22 修正 Ventura 视频写入器拒绝 IEC_sRGB 参数、导致启动录制停留在等待首帧的问题。传统采集与视频导出使用实际转换后的 Rec.709 画面及一致的颜色标记；编辑预览保持 sRGB。目标电脑的录制、声音与导出仍需实机确认。**

[下载构建 22 的 DMG](https://github.com/lllwuwu25-alt/dogsc/releases/download/intel-app-build-22/DogSC-Intel-v0.1.8-macOS13.dmg) · [发布页面](https://github.com/lllwuwu25-alt/dogsc/releases/tag/intel-app-build-22)。

## 使用流程

1. 在支持 Xcode 26.3 的 Mac 上构建，或在自己的 GitHub 仓库运行 Actions → Intel Ventura build。
2. 构建流程必须依次通过 Python 打包检查、Swift 核心测试、Release 编译、架构/最低系统版本检查、签名检查。
3. 成功后在该次 Actions 的 Artifacts 下载 DogSC-Intel-v0.1.8-macOS13，解压得到 DMG、应用 ZIP、SHA256SUMS 与 BUILD-INFO.txt。
4. 打开 DMG，把 DogSC Intel 拖到“应用程序”。首次启动按引导授权屏幕录制、辅助功能，以及按需开启的麦克风和摄像头。若系统拦截这个未公证的个人构建，到“系统设置 → 隐私与安全性”对该 App 使用“仍要打开”。
5. 先进行下方实机检查，再用于正式素材。

## 构建

构建机需要 macOS、Xcode 26.3 或以上、Python 3、网络。目标电脑无需安装 Xcode。
2017 款 Mac 的原生 Ventura 环境不能运行该版本 Xcode，使用云端构建流程即可。

    bash build-intel.sh

默认使用个人本地 ad-hoc 签名。若构建机有开发者证书，可显式设置 DOGSC_SIGNING_IDENTITY 后运行。
构建结果在 dist/intel/。源代码内不保存证书或密钥。

应用名称为 DogSC Intel，Bundle ID 为 cn.laogou.dogsc.intel。
设置、系统权限与正式版隔离；不会连接原项目的 ARM 安装包更新源。
项目文档类型继续兼容，但测试前请复制项目和录制素材，保留原件。

## 本分支的改动

- 加入旧版 SwiftUI 的双值变化回调、初始回调、焦点样式、焦点范围内的键盘事件处理和视觉动画替代实现。
- 为 Ventura 提供可暂停的主线程帧时钟；较新系统仍用原生 CADisplayLink。暂停预览时停止定时器。
- Retina、缩放显示、多显示器窗口录制使用旧系统可取得的显示尺寸计算；录制对象 ID 仍严格保留。
- 摄像头、麦克风、外接设备和连续互通相机使用对应系统版本的发现接口。Ventura 的摄像头预览在主线程显示，较新系统保留原生后台渲染。
- Ventura 的加减步进按钮使用单次点击，不启用新版系统的长按连发。
- Ventura 的源预览缩略图使用一次性 Quartz 截图；显示器预览排除本 App 的窗口。
- 保留现有 ScreenCaptureKit 系统声音回退；不在 Ventura 调用新版 Core Audio Tap。
- 本地化在旧系统使用 Combine 通知，新系统继续保留 Observation 跟踪。
- 独立构建与更新身份；封装所有字体、语言文件、图标、教程资源和 Sparkle 框架。
- 录制、预览与设置动画的 Foundation 定时回调显式进入 MainActor，停止、暂停或重开后丢弃旧回调。

## 实机验收

先以 1080p / 30 FPS / H.264 为基线；这只是测试基线，不是人为锁定导出上限。

- 全屏、单窗口、选区各录制 20 秒；核对尺寸、Retina 清晰度、窗口移动后的区域。
- 分别测试系统声音、麦克风、二者同时录制；暂停/继续后核对音画同步。
- 有设备时测试摄像头、设备热插拔和 iPhone/iPad 数据线录制。
- 调整鼠标效果、自动缩放、背景、圆角和屏幕 3D，确认预览可见。
- 分割/裁剪/撤销/重做，保存项目，退出后重新打开；导出 MP4 并用 QuickTime 播放。
- 在文本框输入时测试方向键和回车；确认不会误触其他控件。
- 切换中英文，确认录制状态、未保存项目和编辑位置没有丢失。
- 缩小、遮挡、切换应用后恢复预览，确认没有黑屏和持续后台渲染。

硬件性能、权限稳定性、键盘细节和旧系统语言刷新仍需上述实际运行检查。
macOS 新版上的成功编译不能替代 Ventura 实机验收。
