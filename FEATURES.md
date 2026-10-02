# 功能差异与验证记录

对照：本机 `/Applications/QLMarkdown.app`，版本 **1.5.2**；本项目 **1.3**。更新日期：2026-10-03。原版对照日期：2026-10-02。

原版的功能清单取自其随包 README；行为证据来自只读调用原版 CLI（命令行选项仅作用于本次转换，不修改应用设置）。**文档列出、当前配置生效、实际验证通过是不同结论。** 本表不宣称逐项完全等价。

## 本轮补齐的常用能力

| 能力 | 原版证据 | 本项目 1.2 | 验证 |
| --- | --- | --- | --- |
| TextBundle | 文档列出；CLI 成功读取样例正文及包内图片 | 支持版本 1/2 的 Markdown 包；正文缺失/多份/不支持类型明确报错 | `Notebook.textbundle`、渲染测试、WebKit 图片检查 |
| 标题锚点 | CLI 验证中文标题及重名 `-1` 后缀 | 自动生成中文/英文锚点，重名去重 | `features.md`，DOM 中验证两个不同 ID |
| 文档目录 | 原版 README 未列出目录开关；此项未声称对齐原版 | 新增设置开关，支持 `[TOC]` / `[[TOC]]` | WebKit 验证目录项与标题数量一致 |
| GitHub 提示块 | 随包文档列出；本机 CLI 当前配置把 `[!NOTE]` 保留为普通引用 | Note、Tip、Important、Warning、Caution 五类 | WebKit 验证 5 个提示块；代码中的标记不转换 |
| YAML front matter | CLI `--yaml all` 输出结构化表格 | **部分对齐**：自动分离并以可折叠原文显示，不解析 YAML 值或执行标签 | 验证嵌套文本保留、正文不变、未闭合头不吞正文 |
| 内嵌 HTML | CLI `--raw-html on` 保留 details 等原始 HTML | 明确开关，默认关；开后支持排版 HTML，DOMPurify 清理事件/脚本/表单等；移除时显示提示 | WebKit 验证 details、checkbox、本地图片保留，危险元素与事件不执行 |
| 远程图片 | 文档及生成 HTML 支持外部图片；未访问原版外链做实测 | 明确开关，默认关；开后加载 HTTP/HTTPS，失败显示具体提示 | 临时回环 HTTP 服务验证一张成功、一张 404；默认关闭验证无网络请求 |

HTML 支持的是文档排版，不复刻原版的 unsafe HTML/unsafe URL 模式。YAML 原文展示与原版的结构化展示是明确差异。

## 已有能力

| 能力 | 本项目情况 | 证据与边界 |
| --- | --- | --- |
| 标题、列表、引用、链接、表格、任务列表、删除线、自动链接、脚注 | 已支持 | cmark-gfm；渲染断言与 Finder 基础样例 |
| 中文、深浅色、字号、内容宽度 | 已支持 | Finder 浅/深色及设置传递已验证 |
| 代码高亮 | 已支持，非同一高亮引擎 | highlight.js；原版使用 Highlight，语言覆盖和配色不保证一致 |
| 本地图片、相对路径、HTML 图片 | 已支持 | 原生嵌入 data URI；单图上限 10 MB |
| Mermaid 围栏、独立 `.mermaid` | 已支持 | Finder 流程图、时序图、独立文件；错误样例含有效饼图 |
| 数学公式 | 已支持常用写法 | `$`、`$$`、`\(`、`\[`、美元反引号、math 围栏；8 个 SVG 公式、矩阵与多行对齐 |
| 图表/公式离线运行 | 已支持 | WebKit 检查零外部资源；不从网络下载脚本或字体 |
| 坏图表/公式 | 明确报错并继续处理其他项 | 错误样例中 2 处错误及后续有效公式/图表 |
| 多种 Markdown 文件后缀 | 基础支持 | 现有 UTI 声明；`.rmd`/`.qmd` 不执行代码，MDX 不执行 JSX；未逐个完成 Finder 验证 |

## 尚未实现或未对齐

| 功能 | 状态 |
| --- | --- |
| 定义列表、`==高亮==`、上下标语法 | 未实现这些 Markdown 扩展（数学公式中的上下标已支持） |
| Emoji 短码、GitHub mentions、Hashtags、Wikilinks | 未实现；Unicode emoji 本身可显示 |
| MKDocs Admonition | 未实现；本轮支持的是 GitHub 提示块 |
| 自定义 CSS/主题导入、行号、Tab 宽度、代码折行开关 | 未实现设置界面 |
| 智能引号、软换行选项、单波浪线删除线、源码模式 | 未对齐原版选项；当前固定 GFM 默认行为和双波浪线删除线 |
| YAML 结构化字段表格 | 未实现，保留原文显示 |
| TextPack 压缩包 | 未实现；本轮仅 TextBundle 目录包 |
| CLI 产品、快捷指令扩展、HTML 导出 | 未提供用户级入口；测试工具不算产品功能 |
| 自动更新、通知捐赠、宣传页脚 | 不加入；广告是本项目明确排除的功能 |

原版 CLI 的 `extensions.md` 样例在当前配置下将 Emoji 短码转为 emoji、单波浪线转为删除线；定义列表、高亮、上下标、Wikilinks、Hashtags、mentions 和 MKDocs 样例仍为普通文字。这只说明该次配置的输出，不代表原版无法开启对应功能。

实际 Finder 已验证 TextBundle 正文与包内图片、GitHub 提示块、目录锚点跳转、HTML 排版与公式共存、远程图片成功及 404 提示。测试设置已恢复关闭，临时 HTTP 服务已停止。

## 如何复验

```sh
Scripts/test.sh
/Applications/QLMarkdown.app/Contents/Resources/qlmarkdown_cli --raw-html on --heads-anchor on --yaml all -o build/upstream-features.html Fixtures/features.md
/Applications/QLMarkdown.app/Contents/Resources/qlmarkdown_cli --inline-images on -o build/upstream-textbundle.html Fixtures/Notebook.textbundle
/Applications/QLMarkdown.app/Contents/Resources/qlmarkdown_cli -o build/upstream-extensions.html Fixtures/extensions.md
```

测试报告：`build/web-features-result.json`、`build/web-textbundle-result.json`、`build/web-remote-result.json`；已有数学/图表报告为 `build/web-rich-result.json`、`build/web-dark-result.json`、`build/web-error-result.json`。

格式参考：[TextBundle 规范](https://textbundle.org/spec/)；HTML 清理组件：[DOMPurify](https://github.com/cure53/DOMPurify)。

## 1.3 新增（2026-10-03）

- 图表缩放、实际大小、适应宽度、横向滚动；包含 60 节点样例。
- 请求级 8 秒超时、任务取消、单后台操作限制；网页取消及有限等待。同步调用无法中途抢占，详见 README。
- 文档、图片字节/像素、图表、公式和代码高亮限制，所有跳过或失败均显示提示。
- 自绘应用图标、本机架构 DMG、SHA-256 校验、升级备份与失败恢复、移到废纸篓的卸载流程。
- 开发签名，未公证；其他 Mac 的分发验证不在本轮完成范围内。
