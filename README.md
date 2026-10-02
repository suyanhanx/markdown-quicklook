# Markdown Quick Look

独立的 macOS Markdown Quick Look 插件，参考现有 Markdown 预览的排版习惯重新实现。应用和扩展代码独立编写，不依赖或修改 QLMarkdown。没有宣传页脚、捐赠提示、预览计数器或自动更新。

## 使用

打开 `/Applications/Markdown Quick Look.app` 调整字号、内容宽度、深浅色主题，以及目录、HTML 排版和远程图片开关。设置自动保存，关闭并重新打开预览后生效。

在 Finder 里选择 `.md` / `.markdown` / `.mermaid` 文件或 `.textbundle` 包，按空格。扩展标识为 `local.yan.MarkdownQuickLook.Preview`。

已实现：UTF-8 中文、GitHub 风格表格、任务列表、删除线、自动链接、脚注、代码高亮、本地图片、Mermaid 图表与 LaTeX 数学公式。解析库为 cmark-gfm，代码高亮为 highlight.js 11.11.1，图表为 Mermaid 11.12.0，公式为 MathJax 3.2.2 SVG；运行时不下载依赖或字体。

1.2 新增 TextBundle、中文标题锚点、目录、五类 GitHub 提示块、可折叠 YAML 元信息，以及可选的 HTML 排版和远程图片。目录可通过设置或正文中的 `[TOC]` / `[[TOC]]` 启用。YAML 保留原文，不转换成结构化表格。

HTML 与远程图片默认关闭。HTML 开启后由 DOMPurify 3.4.16 清理，不执行脚本；移除内容时显示提示。远程图片关闭或加载失败、本地图片读取失败均显示明确提示。文档限制 20 MB，单张本地图片限制 10 MB。完整对照及未实现项目见 [功能差异表](FEATURES.md)。

## 构建

要求：Xcode、CMake、XcodeGen、本机 Apple Development 签名证书。

```sh
export PATH="/opt/homebrew/bin:$PATH"
security find-identity -v -p codesigning
SIGNING_IDENTITY='你的 Apple Development 证书名称或指纹' Scripts/build.sh
Scripts/test.sh
Scripts/install.sh
```

构建当前机器架构。第三方 C 库固定在 Git submodule 提交中，highlight.js 随源码保存。Xcode 编译后使用本机证书签名，不调用 Apple 开发者门户，也不申请 provisioning profile。

安装脚本仅替换本项目自己的应用，旧构建会备份至 `~/Library/Application Support/Markdown Quick Look/Backups/`，不会修改或卸载 QLMarkdown。切换回原扩展可在系统 Quick Look 扩展设置中选择，或重置本扩展偏好：

```sh
pluginkit -e default -i local.yan.MarkdownQuickLook.Preview
qlmanage -r
```

## 验证

`Scripts/test.sh` 验证 Markdown 功能、HTML 安全处理、明确错误和连续 101 次渲染。还会启动 WebKit 验证浅色/深色下的 8 个公式、流程图、时序图、错误后的继续渲染，以及默认零网络请求。1.2 通过 232 项原生渲染检查，并增加 WebKit 对目录、提示块、HTML 清理、TextBundle 和图片失败提示的验证；远程图片开启路径由临时回环 HTTP 服务验证成功图片及 404。产物在 `build/preview.html`、`build/rich-preview.html` 和 `build/web-*-result.json`。

2026-10-02 已在本机完成 Release 构建、签名验证，以及 Finder 中的浅色/深色预览、代码高亮、表格、本地 SVG 图片、脚注、Mermaid 流程图/时序图与数学公式检查。1.2 还在实际 Finder 验证了目录跳转、HTML 排版、TextBundle 正文/包内图片/提示块，以及 HTTP 图片成功加载和 404 提示。应用设置正确传递到扩展，测试后目录、HTML、远程图片开关均恢复关闭。`qlmanage -p -o` 在本机 ExtensionFoundation 内部崩溃；该命令不作为成功依据，已改用真实 Finder 预览验证。

## 代码结构

- `App/`：SwiftUI 设置窗口。
- `Extension/`：Quick Look 数据型扩展。
- `Shared/`：GFM 渲染和共享偏好。
- `Resources/`：独立 CSS 和随包提供的高亮脚本。
- `Fixtures/`、`Tests/`：可重复运行的验证样本。

## 第三方许可

cmark-gfm：见 `Vendor/cmark-gfm/COPYING`（MIT 等上游声明）。
highlight.js：见 `Resources/highlight-LICENSE.txt`（BSD-3-Clause）。
DOMPurify：见 `Resources/dompurify-LICENSE.txt`（Apache-2.0 或 MPL-2.0）。

## 图表和公式

在标记为 `mermaid` 的围栏代码块中写图表，也可直接预览 `.mermaid` 文件。主题跟随预览的浅色/深色设置。

数学支持 `$...$`、`$$...$$`、`\(...\)`、`\[...\]`、GitHub 的美元加反引号写法，以及标记为 `math` 的围栏代码块。公式在 Markdown 解析前保护，避免下标、反斜杠和矩阵换行被改变；普通代码中的美元符号保持原样。

图表或公式语法有误时，预览显示明确错误及原始输入，并继续渲染后面的有效内容。MathJax SVG 不需要外部字体。普通 Markdown 文件不会嵌入这些较大的数学/图表脚本。

Mermaid：`Resources/mermaid-LICENSE.txt`（MIT）。MathJax：`Resources/mathjax-LICENSE.txt`（Apache-2.0）。下载来源与校验值见 `Resources/libraries.json`。

## 1.3：稳定性、图表阅读与交付

图表有“缩小 / 放大 / 实际大小 / 适应宽度”按钮，缩放范围 10%–400%（适应宽度可更小），支持横向和纵向滚动与键盘聚焦。窗口宽度变化时，适应宽度模式会重新计算比例。

预览请求整体等待上限 8 秒，覆盖偏好设置读取、文件读取与 Markdown 处理。任务取消会立即结束等待，后台在检查点退出；每个扩展进程只允许一个后台操作，避免系统 I/O 阻塞时不断堆积线程。同步系统调用及 C 解析不能中途抢占；若旧操作尚未返回，新请求明确报忙。

网页渲染在项目之间让出执行权，提供“取消渲染”按钮和页面关闭取消。整体检查期限 30 秒，单次图表异步等待 5 秒；JavaScript 的同步布局不能被同线程计时器强行打断，因此也限制输入复杂度。超限显示错误与原文，不悄悄切换渲染器。

| 对象 | 限制 |
| --- | --- |
| Markdown | 20 MB |
| 本地图片 | 单图 10 MB，累计 20 MB；栅格图最多 4000 万像素 |
| 生成正文 | 48 MB |
| Mermaid | 最多 20 张；每张 20000 字符、400 行，布局引擎最多 200 条边 |
| 数学 | 最多 200 项，单项 10000 字符 |
| 代码高亮 | 超过 50000 字符时明确提示并保留代码原文 |
| 图片等待 | 15 秒后显示加载失败 |

新增验证：约 1 MB 文档、超过 20 MB 文件、超过 10 MB 图片、60 节点图表、超限图表、缩放/滚动、主动取消、模拟永久等待超时、后台忙状态和恢复。原生请求的超时测试使用可控阻塞，不依赖偶然的慢机器。

图标为项目自绘，源文件 `Scripts/make-icon.swift`，生成后使用 `iconutil` 制作 `App/AppIcon.icns`。应用版本从 Info.plist 读取。

DMG、签名验证、升级备份/失败回滚和可恢复卸载见 [安装说明](INSTALL.md)。本机已验证升级、卸载后重装和注入注册失败后的恢复；本轮没有公证或对外发布。

2026-10-03：1.3 在实际 Finder 完成 60 节点图表、100%/125% 缩放与横向滚动验证。完整测试通过 241 项渲染断言、10 个 WebKit 场景及请求级超时/取消/忙状态/恢复检查。测试过程中发现系统偏好读取曾阻塞，已将其纳入请求级超时保护；不以普通渲染检查替代这个边界。

## 1.4：渲染占位与进度

所有公式和 Mermaid 图表在计算开始前统一变成占位骨架，明确区分“排队中”和“正在渲染”。图表和块级公式预留空间，行内公式使用紧凑占位；顶部显示已处理数量及取消按钮。成功后替换为内容，失败、取消和超时后替换为错误及原文，不留下永远加载的骨架。动画遵循系统减少动态效果设置。

新增 WebKit 延迟渲染场景：验证两张图表分别处于正在渲染和排队状态、源码已收起、进度为 0/2，并确认完成后全部占位消失。现有取消和超时场景也检查无残留占位。
