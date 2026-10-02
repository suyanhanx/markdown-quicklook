---
title: 功能兼容性验证
tags:
  - markdown
  - quicklook
nested:
  value: "<script>不执行</script>"
---

# 功能兼容性验证

[TOC]

## 中文 标题

[跳转到中文标题](#中文-标题)

## 中文 标题

第二个同名标题应该使用唯一锚点。

> [!NOTE]
> 普通备注，支持 **加粗**。

> [!TIP]
> 这里是提示。

> [!IMPORTANT]
> 这里是重要信息。

> [!WARNING]
> 这里是警告。

> [!CAUTION]
> 这里是注意事项。

## HTML

<details open><summary>展开详情</summary><p>详情中可以包含 <kbd>⌘</kbd> 和 <mark>高亮</mark>。</p></details>

<img src='sample.svg' alt="HTML 本地图片" onerror="window.PWNED=1">

<a href="javascript:window.PWNED=1">危险链接不执行</a>

<iframe src="https://example.com/"></iframe>

<script>window.PWNED=1</script>

## 数学仍然正常

公式 $x_i=\frac{1}{2}$。

## 普通 Markdown

| 功能 | 结果 |
| --- | --- |
| 表格 | 保留 |

- [x] 任务列表

```js
const marker = '[!NOTE]';
```
