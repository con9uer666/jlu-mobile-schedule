# iOS 调试手册

Windows 这边写代码,远程 Mac 只负责编译签名。本文档列在 Mac 上一步步要做的事。

> **前提**:Mac 已装 Xcode(15.3+,因为部署目标是 iOS 17)。代码已用 rsync / scp / git 同步到 Mac。

---

## 0. 首次准备(只做一次)

### 0.1 装 CocoaPods

```bash
# 走 Homebrew(推荐,跟系统 Ruby 解耦)
brew install cocoapods

# 或者系统 Ruby
sudo gem install cocoapods
```

装完 `pod --version` 出 1.15+ 就行。

### 0.2 Flutter SDK

远程 Mac 上装一份 Flutter(跟 Windows 这边版本对齐):

```bash
git clone --depth 1 --branch stable https://github.com/flutter/flutter.git ~/flutter
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
flutter doctor
```

`flutter doctor -v` 里 iOS 那块要全绿(Xcode / CocoaPods)。

### 0.3 拉工程 + pod install

```bash
cd ~/schedule          # 项目根
flutter pub get
cd ios
pod install
```

第一次 pod install 会把 `Pods/` 和 `Podfile.lock` 建出来,下次只在 `pubspec.yaml` 里 iOS 插件变化时才需要再跑。

---

## 1. 在 Xcode 里加 Widget Extension Target

打开 workspace(**不是** `.xcodeproj`):

```bash
open ios/Runner.xcworkspace
```

1. 菜单 **File → New → Target…**
2. 选 **Widget Extension**,点 Next
3. 参数填:
   - **Product Name**: `ScheduleWidget`(大小写必须一致,Dart 侧 `WidgetBridge._iosName` 就是这个)
   - **Team**: 你的个人 Apple ID
   - **Bundle Identifier**: 自动变成 `com.jlu.schedule.ScheduleWidget`
   - **Include Configuration Intent**: **不勾**(我们是静态小组件,不需要用户配置)
4. 点 Finish。弹出 "Activate ScheduleWidget scheme?" 选 **Cancel**(继续用 Runner scheme 调试 app,widget 会被自动 embed)。

Xcode 会在项目里新建一个 `ScheduleWidget/` 文件夹,里面自动生成了模板 Swift 文件。

### 1.1 替换生成的模板文件为项目源码

Xcode 默认生成的文件 **不要用**,用仓库里 `ios/ScheduleWidget/` 下的 4 个文件替换:

1. 在 Xcode 的 Project Navigator 里,选中 `ScheduleWidget` 文件夹里**除 Info.plist 以外**的所有 `.swift` 文件(通常是一两个模板 swift),右键 → **Delete** → **Move to Trash**。
2. 右键 `ScheduleWidget` 文件夹 → **Add Files to "Runner"…**
3. 定位到 `ios/ScheduleWidget/`,选这 4 个文件:
   - `TodayPayload.swift`
   - `ScheduleProvider.swift`
   - `ScheduleViews.swift`
   - `ScheduleWidgetBundle.swift`
4. 对话框底部:
   - **Copy items if needed**: **不勾**(文件已经在仓库里,不想重复复制)
   - **Create groups**: 勾
   - **Add to targets**: **只勾 `ScheduleWidget`**,**取消 Runner**

添加完后 Build Navigator 里 ScheduleWidget target 下应该能看到这 4 个文件,Runner target 下看不到。

---

## 2. App Group capability

小组件和主 app 通过 App Group `group.com.jlu.schedule` 共享 UserDefaults,需要在两个 target 都启用。

### 2.1 Runner target

1. Project Navigator 选最顶上的 **Runner**(蓝色图标),右边选 **Runner** target(注意是 target,不是 project)。
2. 顶部切到 **Signing & Capabilities** 标签。
3. 左上 **+ Capability**,搜 "App Groups",双击添加。
4. 在 App Groups 列表下 **+**,输入 `group.com.jlu.schedule`,勾上。
5. 如果报 "Failed to update provisioning profile",保证 Team 选了你的 Apple ID,再点一下 **Try Again**。

### 2.2 ScheduleWidget target

同样操作:选 **ScheduleWidget** target → **Signing & Capabilities** → **+ Capability** → **App Groups** → **+** → `group.com.jlu.schedule` → 勾上。

两个 target 勾的必须是同一个 group id。

---

## 3. Signing

两个 target 都要配:

- **Team**: 你的 Apple ID(个人 free 账号也行)
- **Automatically manage signing**: 勾
- **Bundle Identifier**:
  - Runner: `com.jlu.schedule`(已有)
  - ScheduleWidget: `com.jlu.schedule.ScheduleWidget`(Xcode 生成的默认值就行)

> **签名额度提醒**:free 账号 7 天内最多 10 个新 App ID。主 app + widget = 2 个 ID,安装成功之后不会再消耗;只有"第一次使用新 bundle id 打包"才扣。
> 同时设备上最多 3 个 free 签名 app(另一个开发中的项目已经占了 1 个,这个装上去会占第 2 个)。

---

## 4. Deployment target

- **Runner** target → **General** → **Minimum Deployments** → iOS **17.0**
- **ScheduleWidget** target → **General** → **Minimum Deployments** → iOS **17.0**

如果 Runner 之前是 12/13 之类的老版本,改成 17 之后 Flutter 部分没影响,但 Podfile 也得同步:

```ruby
# ios/Podfile 顶部
platform :ios, '17.0'
```

改完重新 `pod install`。

---

## 5. 编译 & 装机

### 5.1 连 iPhone

用数据线或 Wi-Fi 连上 iPhone,Xcode 顶栏设备选择器切成你的 iPhone。

第一次跑可能要在手机上 **设置 → 通用 → VPN 与设备管理 → 开发者 App** 手动信任开发者证书。

### 5.2 命令行构建 .ipa(推荐,走爱思助手装)

```bash
cd ~/schedule
flutter build ipa --release
```

产物在 `build/ios/ipa/schedule.ipa`,下载到 Windows 用爱思助手侧载即可。

`flutter build ipa` 第一次跑会要求选 export method,选 **Development** 即可(对应 free 账号签名)。

### 5.3 直接从 Xcode 跑(更方便调试)

Xcode 顶栏左侧选 **Runner** scheme,设备选你的 iPhone,点 ▶️。
首次跑会在 iPhone 上安装,同时 widget extension 会一并 embed 进去。

---

## 6. 验证 widget

1. app 启动一次(否则 App Group 里还没数据)。
2. 回到 iPhone 桌面 → 长按空白处 → 左上 **+** → 搜 "课程表" → 加小组件 → 选 small / medium / large。
3. widget 上应该出现今日课程。点一个课程,app 会启动并弹出详情下拉。
4. 如果 widget 一直显示 "今日无课":
   - 确认 App Group id 两边一致(`group.com.jlu.schedule`)
   - 确认 ScheduleWidget target 上也加了 App Groups capability
   - app 里改一下课表让 `HomeWidget.saveWidgetData` 再跑一次,然后桌面上 widget 几秒内会刷

---

## 7. 反向同步产物到 Windows

打完 ipa 之后:

```bash
# 在 Mac 上
scp build/ios/ipa/schedule.ipa user@windows-host:/path/...
# 或者 rsync / SMB / 其他你们用的通道
```

Windows 这边用爱思助手 → 我的设备 → 应用 → **安装应用**,选 .ipa 拖进去就完事。

---

## 附:常见坑

| 现象 | 原因 | 解决 |
|---|---|---|
| widget 空白 / "今日无课" | App Group 没对齐 | 两个 target 的 App Groups 都要勾 `group.com.jlu.schedule` |
| Runner 编译报 `FlutterImplicitEngineBridge` 找不到 | Flutter SDK 太旧 | `flutter upgrade` 到 3.35+ |
| pod install 卡在 `Updating local specs repositories` | CocoaPods repo 国内慢 | 用国内镜像:`pod repo-add trunk https://cdn.cocoapods.org/` 或设代理 |
| 点 widget 进 app 没弹详情 | URL scheme 没注册 / MethodChannel 没连上 | 确认 Info.plist 里 `CFBundleURLSchemes` 有 `schedule`;确认 Dart 起来后才打印 widget_launch_handler 的日志 |
| widget ListView 刷不出最新课程 | home_widget 只在 Dart 侧主动调用 updateWidget 时刷 | Dart 里 `WidgetSync` 已经在 semester / courses 变时自动推,不用手动 |
| 装到手机报 "无法安装" | 签名额度满 | 删一个别的 free 签名 app 再装 |
