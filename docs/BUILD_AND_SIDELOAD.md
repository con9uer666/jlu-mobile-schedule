# iOS 打包与安装流程

整个链路:Windows 写代码 → 同步到远程 Mac → Mac 打包 → .ipa 回传 → 爱思助手侧载。

## 一次性准备

### 远程 Mac 上

```bash
# 装 Flutter 3.41 或更高
# 装 CocoaPods
sudo gem install cocoapods

# 装 Xcode(从 App Store),启动一次接受协议
sudo xcodebuild -license accept
```

### 代码同步

推荐用 git(搭个私有仓库:GitHub / Gitee 都行),或者直接 rsync / scp。

```bash
# 在 Mac 上第一次拉代码后
cd schedule
flutter pub get
cd ios && pod install
```

### Xcode 配签名(只做一次)

1. 打开 `ios/Runner.xcworkspace`(**注意是 workspace 不是 xcodeproj**)
2. 选中左侧 Runner 项目 → Signing & Capabilities
3. Team 下拉选你用 Apple ID 登录后的 **Personal Team (你的名字)**
4. Bundle ID 已经是 `com.jlu.schedule`,如果 Xcode 报这个 ID 被别人占了,改成 `com.jlu.schedule.你名字拼音`
5. Xcode 会自动申请一张**免费 Apple Development 证书**和 provisioning profile

## 每次打包

Mac 上:

```bash
cd schedule
flutter pub get
flutter build ios --release --no-codesign
# 上面这步其实已经在 build/ios/iphoneos/Runner.app 产出未签名 .app

# 要给爱思助手用的 .ipa,推荐用 xcodebuild archive + exportArchive 导出 development ipa
flutter build ipa --export-method development
# 产物在 build/ios/ipa/schedule.ipa
```

如果 `flutter build ipa` 因为 signing 报错,走 Xcode GUI:
- Product → Archive → 完成后打开 Organizer → Distribute App → Debugging → 选 Development profile → Export → 得到 ipa 目录

把 `schedule.ipa` 传回 Windows。

## 爱思助手侧载

1. Windows 装爱思助手(i4Tools),打开,用数据线连 iPhone
2. 手机上信任电脑
3. 爱思主界面 → 应用游戏 → 左下角 **安装本地应用** → 选 `schedule.ipa`
4. 第一次装完会提示签名,爱思会问用**原 ipa 自带签名**还是**用你的 Apple ID 重签**
   - 如果 ipa 是 Mac 上用你自己 Apple ID 导出的 development ipa,选**保留原签名**即可
   - 如果想换个 Apple ID 签,选**自签名**,填 Apple ID
5. 手机上第一次打开要去 设置 → 通用 → VPN 与设备管理 → 信任你的开发者账号

### 有效期与续签

- 个人免费证书:**7 天有效**,到期后 app 点开秒闪退
- 爱思助手有**自动续签**功能:工具箱 → 应用签名,输入 Apple ID 后可以对装好的 app 直接续签,不用重装
- 续签期间手机需要连着电脑 + 爱思

### 个人证书的 app 数量限制

免费 Apple ID **最多同时装 3 个自签 app**,当前这个就算一个。

## 抓包(让我实现教务登录用)

等 app 架子跑通后,我需要你抓一次真实的登录和课表请求,才能让代码对得上。

### 方式 A:浏览器 F12(最简单,推荐先试)

1. Chrome 打开 https://iedu.jlu.edu.cn/jwapp/sys/wdkb/*default/index.do?THEME=indigo&EMAP_LANG=zh#/xskcb
2. **F12 打开开发者工具 → Network 标签 → 勾选 Preserve log**
3. 正常登录、进入课表页
4. 完成后在 Network 里全选所有请求 → 右键 → **Save all as HAR with content**
5. 把这个 .har 文件给我(或者挑几个关键请求:`login` / `authserver` / `kbcx` / `cjcx` / `wdkb` 相关的,右键 Copy as cURL (bash))

### 方式 B:Charles / Fiddler(更全,能抓手机 App)

只有在方式 A 拿不到的东西(比如某些请求是手机端独有的)时再用。

### 我需要从抓包里看到的东西

- 登录请求的完整 URL、method、表单字段名(通常是 `username` / `password` 但有可能加密)
- 登录后重定向链路(CAS 的 ticket 参数)
- 课表接口 URL,一般长这样:`/jwapp/sys/wdkb/modules/xskcb/xskcb.do`
- 课表响应 JSON 的字段结构

把这些给我,我就能写对应的爬虫模块了。
