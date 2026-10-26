# Markdown Quick Look

在 macOS Finder 中按空格预览 Markdown，支持代码高亮、Mermaid 图表和 LaTeX 公式。

## 使用

安装后，在 Finder 中选中 `.md`、`.markdown`、`.mermaid` 文件或 `.textbundle` 包，按空格预览。

打开 **Markdown Quick Look** 应用可调整字号、内容宽度和主题。更改设置后，重新打开预览即可生效。

## 构建与安装

需要 macOS 13 或更高版本、Xcode、CMake、XcodeGen 和本机 Apple Development 签名证书。

```sh
git clone --recurse-submodules https://github.com/suyanhanx/markdown-quicklook.git
cd markdown-quicklook

security find-identity -v -p codesigning
SIGNING_IDENTITY='你的证书名称或指纹' Scripts/build.sh
Scripts/install.sh
```

构建产物使用当前机器架构，尚未公证。升级、卸载和打包方法见 [安装说明](INSTALL.md)。

## 许可证

Copyright © 2026 suyanhanx. 本项目原创代码以 [Apache License 2.0](LICENSE) 发布。

第三方依赖遵循各自的许可证，原文随源码保留：

| 依赖 | 许可证 |
| --- | --- |
| cmark-gfm | [COPYING（含各部分许可声明）](Resources/cmark-COPYING.txt) |
| highlight.js | [BSD-3-Clause](Resources/highlight-LICENSE.txt) |
| Mermaid | [MIT](Resources/mermaid-LICENSE.txt) |
| MathJax | [Apache-2.0](Resources/mathjax-LICENSE.txt) |
| DOMPurify | [Apache-2.0](Resources/dompurify-LICENSE.txt) |
