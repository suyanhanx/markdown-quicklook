# 安装、升级与卸载

本项目当前为 1.6，最低 macOS 13。安装包名称标明处理器架构；目前构建的是本机架构，不是通用二进制。

## 安装或升级

1. 退出正在运行的 Markdown Quick Look 设置窗口，并关闭 Finder 的预览窗口。
2. 打开 DMG，运行 `Install.command`。也可以把应用拖到 Applications，但拖放不会替你备份旧版本或显式选择扩展。
3. 打开 Applications 中的 Markdown Quick Look；需要时在系统扩展设置中启用它。
4. Finder 选中 Markdown 按空格，关闭旧预览再重新打开。

脚本验证应用标识、代码签名和版本号，拒绝替换其他应用或降级。新文件复制和校验完成后才替换旧版本；后续注册失败会尝试恢复旧应用并明确报告结果。旧版本保存到 `~/Library/Application Support/Markdown Quick Look/Backups/`，设置保留。源代码安装可运行 `Scripts/install.sh`。

回滚时，退出应用，把当前版本移到废纸篓，将备份中的应用移回 `/Applications/`，再运行安装脚本并将恢复后的应用路径作为参数。恢复版本后重新打开预览。备份不会自动清理。

## 卸载

退出设置窗口及预览，运行安装包中的 `Uninstall.command` 或源码中的 `Scripts/uninstall.sh`。只注销本项目扩展并将自己的应用移到废纸篓，不修改 QLMarkdown。设置和升级备份保留。需要恢复时，从废纸篓移回应用，再执行安装脚本。

## 打包与分发范围

运行 `Scripts/package.sh`，DMG 和 SHA-256 校验文件生成在 `build/releases/`。

当前使用本机 Apple Development 证书签名，**没有公证**。已验证本机安装，不保证其他 Mac 的 Gatekeeper 接受。对外分发安装包需另行准备 Developer ID Application 证书、目标架构构建、签名、公证与 stapling。
