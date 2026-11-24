# 拷貝閱讀器 · iOS 客户端

拷贝漫画（copy5000 / copy4000）的 iOS 原生外壳。SwiftUI + WKWebView，iOS 15 以上。

官网 download 页写着「IOS (正在開發中)」，只有安卓包。这个工程就是为了补上那个洞。

---

## 先说清楚：IPA 从哪来

我写代码的这台机器是 Android 上的 proot Ubuntu，没有 macOS、没有 Xcode、没有 Apple 签名链，**在这里编译不出 IPA**。iOS 的包必须在 macOS 上由 Xcode 产出，这是苹果的硬限制，没有绕过的办法。

所以给你三条路，按省事程度排序。

### 路线 A：GitHub Actions 白嫖 macOS（推荐）

不需要你有 Mac，不需要装 Xcode，全程浏览器操作。

1. 注册 / 登录 GitHub，新建一个空仓库（Private 也行，Public 免费额度更多）
2. 把本目录整个传上去。网页端可以直接拖文件夹上传，或者用 git：
   ```bash
   cd CopyReader-iOS
   git init && git add -A
   git commit -m "init"
   git branch -M main
   git remote add origin https://github.com/你的用户名/copy-reader-ios.git
   git push -u origin main
   ```
3. push 之后自动开始跑。到仓库的 **Actions** 页看进度，第一次约 8–12 分钟
4. 绿勾之后点进那次运行，页面底部 **Artifacts** 下载 `CopyReader-unsigned-ipa`
5. 解压得到 `CopyReader-unsigned.ipa`

拿到的是**未签名**包，装之前必须自己签一次，见下面「装到手机」。

### 路线 B：有 Mac

```bash
brew install xcodegen
cd CopyReader-iOS
xcodegen generate
open CopyReader.xcodeproj
```

Xcode 里选你的开发者账号（Signing & Capabilities → Team），连上 iPhone 直接 Run。免费账号 7 天过期，付费开发者账号 1 年。

要出 IPA：Product → Archive → Distribute App → Development / Ad Hoc。

### 路线 C：不折腾签名，1 分钟能用

Safari 打开 `https://www.copy5000.com` → 分享 → **添加到主屏幕**。

这不是 App，但表现接近：全屏、有图标、无地址栏、独立入口。广告去不掉，没有本地书签和批量存图。当过渡用足够。

---

## 装到手机（签名这一步必须做）

iOS 不认未签名的包。三个选项：

| 方式 | 成本 | 有效期 | 说明 |
|---|---|---|---|
| Sideloadly + 免费 Apple ID | 0 | 7 天 | 到期重签，电脑上点一下就行 |
| AltStore / SideStore | 0 | 7 天 | 可以自动续签，但要在电脑上跑 AltServer |
| Apple Developer 付费账号 | $99/年 | 1 年 | 最省事，可装 100 台设备 |
| TrollStore | 0 | 永久 | 只限 iOS 14–17.0 特定版本，能装就装 |

**Sideloadly 步骤**（Windows / Mac 都行）：

1. 装 iTunes（Windows 需要，提供驱动）和 Sideloadly
2. iPhone 连电脑，信任这台电脑
3. Sideloadly 里拖进 `CopyReader-unsigned.ipa`
4. Apple ID 填自己的，点 Start，输密码
5. 手机上：设置 → 通用 → VPN 与设备管理 → 信任你的开发者证书
6. 打开 App

7 天后打不开，重新跑一遍第 3–5 步即可，数据不会丢。

---

## 做了什么

不是套个浏览器就交差。这个壳处理了这类站在 WebView 里的实际问题：

**导航**
- 单页应用式的站内跳转全部留在 App 内
- `target="_blank"` 的章节链接在同一个 WebView 里打开（不处理的话点不动，这是最常见的坑）
- `itms-apps://`、`mqqapi://` 这类广告跳转直接掐掉
- 左滑右滑手势返回

**净化**
- WKContentRuleList 硬屏蔽广告域：exoclick、trafficjunky、doubleclick、googlesyndication、popads、propellerads、adsterra、juicyads、adnium、realsrv、tsyndicate、hilltopads、adcash、clickadu、mgid
- JS 注入盖住 `window.open` 弹窗、`javascript:` 打开的点击劫持
- `<style>` 注入隐藏广告 iframe 容器，MutationObserver 跟进动态插入

**阅读**
- 手机版 / 电脑版 UA 一键切换，电脑版适合横屏看跨页
- 主站 copy5000 与镜像 copy4000 一键互换（同一个 URL 直接换域名，不丢当前页）
- 顶栏进度条、标题、线路标识

**本地**
- 书签（可滑动删除）、最近 200 条阅读记录，UserDefaults 存，不联网
- 长按保存：一键把本页所有有效图片（naturalWidth ≥ 200）下载进相册
- 下载带 `Referer` 和移动端 UA，绕开图片防盗链——直接拿图片 URL 在别处打不开就是这个原因

---

## 已知限制

- **广告拦截改 toggle 要重启 App**。内容规则在 WebView configuration 创建时挂载，现改不生效。
- **不能去登录后的付费章节锁**。这是客户端外壳，不改站点逻辑。
- **站点改版可能需要跟一下选择器**。广告屏蔽靠域名，比较抗改；JS 注入的 CSS 选择器（`ins.adsbygoogle` 等）可能要更新。
- **证书 7 天到期**。免费签名绕不开。
- 站点若启用 Cloudflare 人机验证，部分情况下 WebView 里过不去，属站点侧策略。

---

## 改哪里

```
CopyReader-iOS/
├── project.yml                    XcodeGen 工程描述（Bundle ID、部署版本在这改）
├── CopyReader/
│   ├── CopyReaderApp.swift        @main
│   ├── AppModel.swift             状态、UA、广告规则、镜像切换、JS 注入、图片提取
│   ├── WebView.swift              WKWebView 封装 + 导航/新窗口/跳转策略
│   ├── RootView.swift             主界面、书架、设置
│   ├── LibraryStore.swift         书签与历史
│   ├── ImageSaver.swift           批量下载存相册
│   └── Info.plist                权限、方向、ATS
└── .github/workflows/ios.yml     云端出 IPA
```

换 Bundle ID：改 `project.yml` 里的 `PRODUCT_BUNDLE_IDENTIFIER`。
换默认站点：改 `AppModel.swift` 里的 `Site.primary`。
加广告域：改 `AppModel.swift` 里的 `adRuleJSON`。

---

第三方客户端。所有漫画版权归原作者与站点所有，本工程不存储、不分发任何内容，只是访问层。
