# EverydayCounts

> Every day, once. Every day counts.
> 每天一次，每天都值得。

一款极简的每日影像日记 iOS 应用。默认当日可编辑窗口到本地时区 `23:59:59`，过后该日不可再更新；若当天未记录，可在之后通过「拍照 / 白板 / 文字」补记（仅补该日空位，不覆盖已有记录）。

A minimalist daily photo diary for iOS. One photo per day — one moment, one memory, gone if you miss it.

---

## 功能 Features

- **每日记录 Daily Capture** — 支持 Live Photo、相册图片和截图上传；当日可重新拍摄或替换，4:3 取景框，闪光灯 / 变焦控制，手势捏合调焦
- **今日页 Home** — 以照片为唯一主视觉，日期和操作退到背景，保持安静、克制的记录体验
- **新用户入口 First Run** — 空状态提供一个明确的“拍一张”主入口，同时保留相册、文字和白板记录
- **时间窗与补记规则** — 当日截至 23:59:59 后自动锁定；过期后只允许对空缺日期进行一次性补记
- **白板补记 Sketch Notes** — 白色画布、黑色默认画笔，支持颜色、笔刷粗细和橡皮擦，保存时保留白色背景
- **每日一句 Daily Caption** — 可为照片或白板添加一句说明；照片主体封存后，说明仍可随时编辑或删除
- **防误删备份 Auto Restore** — 照片保存至系统相册专属「Everyday Counts」相册，同时写入本地备份；从相册删除后下次打开自动还原
- **索引恢复 Index Recovery** — 重装或 Bundle ID 变化后，可从「Everyday Counts」系统相册按拍摄日期重建时间线索引，不删除原照片
- **手动恢复 Manual Recovery** — 设置页可查看相册扫描数量与恢复数量，便于确认历史照片是否可被重新索引
- **数据迁移 Migration** — 旧版只有照片字段的 SwiftData 记录会将缺失类型按 `photo` 兼容读取
- **时间线 Timeline** — 月历视图浏览每天的记录，支持点击全屏预览照片/文字/白板
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
