# 吉林大学手机课表

面向吉林大学学生的 Flutter 课表应用，支持教务系统导入、周视图、调课、课程提醒、学习事项、语音快速添加，以及 Android / iOS / macOS 桌面小组件。

## Android 下载

发布版本会随 GitHub Release 提供 APK：

[下载最新 Android APK](https://github.com/con9uer666/schedule/releases/latest/download/jilin-university-schedule.apk)

如果仓库保持私有，下载链接只对仓库成员开放；要让所有用户直接下载，需要将仓库设为公开，或把 APK 放到其他公开文件托管服务。

## 本地开发

需要 Flutter 3.41 或更高版本，以及 Android Studio / Xcode 对应的移动端工具链。

```bash
flutter pub get
flutter test
flutter analyze
```

构建 Android release APK：

```bash
flutter build apk --release
```

产物位于 `build/app/outputs/flutter-apk/app-release.apk`。如果配置了 `android/key.properties` 和对应的私有 keystore，release 会使用正式签名；没有签名文件时仍可使用调试密钥完成本地构建。

## Android 发布签名

不要把 keystore 或 `android/key.properties` 提交到 Git。首次发布后请妥善备份 keystore、别名和密码；后续版本必须继续使用同一签名，否则 Android 会把它识别为不同应用，无法覆盖安装。

## iOS 发布

iOS 可以发布给用户使用，但必须在 macOS 上通过 Xcode 完成 Apple 开发者签名。公开分发通常有两条路径：

- App Store：需要 Apple Developer Program 账号、App Store Connect 元数据审核和正式签名。
- 网站或测试分发：可用 Ad Hoc、TestFlight 或其他合规企业分发方式；个人免费 Apple ID 只适合短期开发测试，不能作为面向所有用户的长期公开下载渠道。

项目已经包含 iPhone、Widget 和 Apple Watch 的工程文件，正式发布前还需要在 Xcode 中配置 Team、Bundle ID、App Groups 和 provisioning profile，并在真机上验证登录、通知、小组件及手表同步。
