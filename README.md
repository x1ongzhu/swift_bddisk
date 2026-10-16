# BaiduNetDisk

极简原生 SwiftUI macOS 百度网盘客户端：文件浏览、上传、下载，以及 URL Scheme 下载。单账号使用，不依赖 Rust 后端或第三方库。

## 构建与运行

需要 macOS 14+ 和 Swift 6.2+（Command Line Tools 或 Xcode）。

```sh
swift build
swift test
./scripts/build-app.sh
open dist/BaiduNetDisk.app
```

也可在 Xcode 中打开 `Package.swift`。URL Scheme 需要使用打包后的 `.app`，单独运行 Swift Package 可执行文件不会注册协议。打包脚本采用本地 ad-hoc 签名；发布版本需要正式签名及公证。

## 登录与操作

1. 打开客户端，使用百度网盘 App 扫描登录二维码。
2. 在手机上确认登录，客户端自动验证账号并进入文件列表。二维码过期或请求失败时，可点击刷新重试。也可以点击“使用短信验证码登录”，在内嵌的百度网盘官方首页点击“去登录”，选择“短信登录”，输入手机号和验证码；通过验证后客户端自动连接。页面的登录方式及额外验证由百度决定。
3. 双击目录进入；双击文件选择下载文件夹。工具栏支持上传、下载和查看传输。
4. 可从 Finder 拖入多个文件上传到当前目录。上传重名文件由服务端自动重命名；下载不覆盖已有文件。

扫码获得的 Cookie 是账号凭据，只保存到本机系统钥匙串；退出登录会移除凭据并取消传输。请不要在 Issue、日志或代码中粘贴真实 Cookie。

快捷键：`⌘⇧U` 上传，`⌘R` 刷新，`⌘J` 查看传输。

## URL Scheme

默认协议下载自己的网盘文件，不接收分享链接。路径必须 URL 编码，客户端会显示下载确认并要求选择本地文件夹。

```sh
open 'baidunetdisk://download?path=%2FDocuments%2Fexample.pdf'
```

首次运行 `.app` 后系统会注册协议。未登录时先登录，再重新打开链接。

## 结构

- `Sources/NetDiskCore/`：Cookie 解析、API、Locate 签名和链接校验。
- `Sources/BaiduNetDisk/`：SwiftUI 界面、应用状态、钥匙串、传输展示。
- `Tests/NetDiskCoreTests/`：Swift Testing，验证签名、凭据、链接及文件解析。
- `scripts/`：本地 `.app` 打包与协议注册配置。

## API 参考与当前范围

接口与签名研究参考 [BaiduPCS-Rust](https://github.com/komorebiCarry/BaiduPCS-Rust)，参考提交 `427c5c38d8589b91c3a5fee09e5c9c246ad7c27e`。此实现使用 Swift 独立编写：列表采用 xpan/file，下载采用 locatedownload，上传采用 precreate、superfile2 和 create。

当前支持文件传输，尚未实现文件夹递归传输、暂停续传、重启恢复和分享链接下载。进度按已完成的分片更新，任务记录仅在当前运行期间保留。百度接口与账号限制可能变化；实际扫码登录、上传和下载需要使用真实账号联调，不保证会员下载速度。

## 本机验证

本机 Command Line Tools 的测试宏插件未被默认后端自动加载。已通过以下命令完成应用编译及全部 8 项核心测试：

```sh
CLANG_MODULE_CACHE_PATH=/tmp/baidunetdisk-clang-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/baidunetdisk-swift-cache \
swift test --disable-sandbox \
  -Xswiftc -load-plugin-library \
  -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib
```

该命令是此工具链的环境适配；正常 Xcode 工具链优先使用 `swift test`。尚未使用真实账号验证接口，已人工确认二维码与短信入口、官方页面加载和短信表单显示；账号验证及文件传输仍未完成真实账号联调。

网页登录使用 WKWebView 的临时数据存储，不与 Safari 共享会话，不持久化网页浏览数据。关闭短信登录窗口会取消会话检测，返回二维码登录。客户端不会读取手机号、验证码或密码输入，仅获取登录后百度域名下的会话 Cookie。
