# Markdown 预览

这是一个**干净、独立**的 Markdown Quick Look 插件。中文、English 和 emoji 🎉 都应正常显示。

## 基础排版

> 好的预览只需要专注于内容。

- [x] 深色与浅色主题
- [x] GitHub 风格表格
- [x] 本地图片
- [ ] 下一步继续完善

| 功能 | 状态 |
| --- | --- |
| **加粗** / *斜体* | 正常 |
| ~~删除线~~ | 正常 |
| `inline code` | 正常 |

## 代码

```swift
struct Preview {
    let title = "Hello, Markdown"
    func render() -> String { title }
}
```

```javascript
const greet = (name) => `Hello, ${name}!`;
console.log(greet("Markdown"));
```

## 图片与脚注

![本地测试图片](sample.svg)

这是一条脚注。[^note]

[^note]: 页面到此结束，没有宣传页脚。
