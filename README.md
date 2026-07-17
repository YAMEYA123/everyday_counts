# EverydayCounts

> Every day, once. Every day counts.
> 每天一次，每天都值得。

一款极简的每日影像日记 iOS 应用。每天只能拍一张照片——一个瞬间，一段记忆，错过即永久失去。

A minimalist daily photo diary for iOS. One photo per day — one moment, one memory, gone if you miss it.

---

## 功能 Features

- **每日拍摄 Daily Capture** — 支持 Live Photo，4:3 取景框，闪光灯 / 变焦控制，手势捏合调焦
- **防误删备份 Auto Restore** — 照片保存至系统相册专属「Everyday Counts」相册，同时写入本地备份；从相册删除后下次打开自动还原
- **时间线 Timeline** — 月历视图浏览每天的记录，支持点击全屏预览 Live Photo
- **回顾视频 Recap Video** — 一键生成月 / 年滑动回顾视频（每张 1.5 秒）
- **连续打卡 Streak** — 统计连续记录天数，✦ 显示在今日页
- **桌面小组件 Widget** — 小 / 中尺寸，展示今日打卡状态与缩略图
- **每日提醒 Reminder** — 可自定义提醒时间，打卡后当天自动取消

## 技术栈 Tech Stack

| 层 | 技术 |
|---|---|
| UI | SwiftUI |
| 数据持久化 | SwiftData |
| 相机 | AVFoundation（AVCaptureSession + AVCapturePhotoOutput） |
| 相册 | PhotosUI（PHPhotoLibrary、PHLivePhotoView） |
| 小组件 | WidgetKit + App Group |
| 通知 | UNUserNotificationCenter |
| 视频生成 | AVAssetWriter |

## 设计 Design

- 应用图标：黑色主色调，浮动日历格样式（白色细线圆角方格 + 顶部标题栏 + 装订孔 + 中心圆点），与应用整体暗黑极简风格一致
- App icon: black-primary, floating calendar tile (white-outlined rounded rect, header strip, binding rings, center dot), consistent with the dark minimalist in-app aesthetic

## 环境要求 Requirements

- iOS 17+
- Xcode 16+
- Bundle ID：`com.yameya.everyday-counts`
- App Group：`group.com.yameya.everyday-counts`

## 构建 Build

```bash
git clone <repo>
open EverydayCounts.xcodeproj
# 在 Xcode 中 Signing & Capabilities 选择自己的 Team，然后 Run
```

> 首次运行需在「设置 → 隐私 → 照片」授予完整访问权限，通知权限在应用内开启。

---

*每天只有一次机会，活在当下。*
