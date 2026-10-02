# Markdown Quick Look

独立的 macOS Markdown Quick Look 插件，参考现有 Markdown 预览的排版习惯重新实现。应用和扩展代码独立编写，不依赖或修改 QLMarkdown。没有宣传页脚、捐赠提示、预览计数器或自动更新。

## 使用

打开 `/Applications/Markdown Quick Look.app` 调整字号、内容宽度和深浅色主题。设置自动保存，关闭并重新打开预览后生效。

在 Finder 里选择 `.md` / `.markdown` 文件，按空格。扩展标识为 `local.yan.MarkdownQuickLook.Preview`。

已实现：UTF-8 中文、GitHub 风格表格、任务列表、删除线、自动链接、脚注、代码高亮和本地图片。解析库为 cmark-gfm，代码高亮为 highlight.js 11.11.1；运行时不下载依赖。

当前范围：不执行原始 HTML；不渲染 Mermaid、数学公式或 TextBundle。远程图片显示明确的未加载提示，本地图片读取失败也显示提示。文档限制 20 MB，单张本地图片限制 10 MB。此版本没有复刻原应用所有扩展功能。

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

安装脚本仅替换本项目自己的应用，旧构建会备份至 `build/install-backups/`，不会修改或卸载 QLMarkdown。切换回原扩展可在系统 Quick Look 扩展设置中选择，或重置本扩展偏好：

```sh
pluginkit -e default -i local.yan.MarkdownQuickLook.Preview
qlmanage -r
```

## 验证

`Scripts/test.sh` 验证 Markdown 功能、HTML 安全处理、明确错误和连续 101 次渲染，并生成 `build/preview.html`。

2026-10-02 已在本机完成 Release 构建、签名验证，以及 Finder 中的浅色/深色预览、代码高亮、表格、本地 SVG 图片和脚注检查。应用设置正确传递到扩展。`qlmanage -p -o` 在本机 ExtensionFoundation 内部崩溃；该命令不作为成功依据，已改用真实 Finder 预览验证。

## 代码结构

- `App/`：SwiftUI 设置窗口。
- `Extension/`：Quick Look 数据型扩展。
- `Shared/`：GFM 渲染和共享偏好。
- `Resources/`：独立 CSS 和随包提供的高亮脚本。
- `Fixtures/`、`Tests/`：可重复运行的验证样本。

## 第三方许可

cmark-gfm：见 `Vendor/cmark-gfm/COPYING`（MIT 等上游声明）。
highlight.js：见 `Resources/highlight-LICENSE.txt`（BSD-3-Clause）。
