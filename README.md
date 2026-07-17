# Everyday Counts

每天一张照片，记录生活流动。

## 功能

- **今天** — 拍摄或选取当日照片，压缩保存到本地
- **时间线** — 月历视图浏览历史照片，点击全屏预览
- **回顾** — 将本月或本年照片生成幻灯片视频并下载

## 技术栈

- Next.js 16 + React 19 + TypeScript
- Tailwind CSS 4
- Dexie.js（IndexedDB，本地存储）
- Canvas API + MediaRecorder（视频生成）
- PWA（可添加到 iOS 主屏幕）
- Cloudflare Pages（静态部署）

## 数据存储

所有照片存储在**设备本地的 IndexedDB**，不上传任何服务器。

## 本地开发

```bash
npm install
npm run dev
```

## 部署

连接 GitHub 仓库到 Cloudflare Pages，构建命令：

```bash
npm run build
```

输出目录：`out`

## 路线图

- [ ] iOS 原生版（Swift/SwiftUI）
- [ ] Live Photo 支持
- [ ] CloudKit 多端同步
