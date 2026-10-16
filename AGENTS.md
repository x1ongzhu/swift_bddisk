# Repository Guidelines

## 项目目标与功能范围

使用 SwiftUI 开发极简原生 macOS 百度网盘客户端，仅保留文件浏览、上传、下载、通过 URL Scheme 下载。保持界面简洁，优先采用系统控件、原生工具栏和文件选择器。未经用户要求，不添加多账号、备份、同步、分享管理或其他扩展功能。

登录支持单账号二维码扫码和内嵌百度官方页面的短信验证码登录。网页登录使用 WKWebView 临时会话，成功后读取百度 Cookie 并验证账号，再将会话保存到钥匙串；不得自建或猜测短信接口，不要求用户手动复制 Cookie。URL Scheme 暂按下载自己网盘中的文件路径实现；兼容其他协议或分享链接前，先确认用户需要的链接格式。

## 项目结构与模块划分

- `Sources/NetDiskCore/`：API 请求、文件模型、凭据解析、Locate 签名和下载链接校验。
- `Sources/BaiduNetDisk/`：SwiftUI 界面、应用状态、钥匙串和传输任务。
- `Tests/NetDiskCoreTests/`：Swift Testing 核心行为测试。
- `scripts/`：`.app` 打包脚本与包含 URL Scheme 注册信息的 `Info.plist`。
- `.agents/skills/`：macOS 设计和 SwiftUI 指导资源，与产品代码分开维护。

## 构建、测试与开发命令

要求 macOS 14+、Swift 6.2+。

- `swift build`：编译应用及核心模块。
- `swift test`：运行核心测试。
- `./scripts/build-app.sh`：生成并本地签名 `dist/BaiduNetDisk.app`。
- `open dist/BaiduNetDisk.app`：启动打包应用，供系统注册协议。

可在 Xcode 打开 `Package.swift`。URL Scheme 必须用打包应用验证。当前 Command Line Tools 的测试宏插件适配命令见 `README.md`。

## 编码风格与架构

Swift 使用四空格缩进；类型采用 `UpperCamelCase`，方法和属性采用 `lowerCamelCase`，文件按主要类型命名。API 解码字段可保留服务端名称。

网络使用 `async/await`，API 状态放在 actor 中，UI 状态使用 `@MainActor @Observable`。保持视图精简，业务逻辑置于模型层。使用系统颜色、SF Symbols，并兼顾浅色、深色和辅助功能。没有配置格式化或 lint 工具；引入第三方框架前先与用户讨论。

## API 参考与安全

接口研究参考 [BaiduPCS-Rust](https://github.com/komorebiCarry/BaiduPCS-Rust)。参考提交及接口映射记录于 `README.md`；修改请求前核对参考实现，避免猜测参数或声称尚未验证的接口已可用。

凭据仅保存到系统钥匙串；不得提交或记录 Cookie、令牌和签名下载链接。外部链接必须校验路径；下载不得覆盖已有文件。上传默认由服务端重命名冲突文件。

## 测试与提交要求

核心逻辑使用描述行为的测试名称，覆盖链接解析、签名向量、响应解析和回归问题；暂无覆盖率门槛。界面改动人工检查浅色、深色、空态和错误态。真实登录与传输需账号联调，明确报告实际执行的检查和未验证项。

根目录尚无 Git 历史。提交使用简短祈使句，例如 `Add transfer cancellation`。PR 说明问题、行为变化和验证结果，关联相关 Issue；界面改动附截图。
