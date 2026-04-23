# flutter_stock_app

股票 MACD 技术分析应用 — Flutter 重构版。

## 功能特性

- [待补充]

## 技术栈

- Flutter 3.24.0 / Dart 3.5.0
- 状态管理：flutter_bloc
- 图表：fl_chart
- 依赖注入：get_it

## 开发环境

```bash
# Flutter 版本管理（fvm）
fvm flutter pub get
fvm flutter run

# 构建 Debug APK
fvm flutter build apk --debug

# 构建 Release APK
fvm flutter build apk --release
```

环境要求：
- Flutter 3.24.0（通过 fvm 管理，路径 `/home/xisang/fvm/versions/3.24.0/`）
- Android SDK / JDK 17
- JAVA_HOME 需指向 JDK 17

## 项目结构

```
lib/
├── main.dart
├── app.dart
├── core/              # 核心配置、主题、路由
├── data/              # 数据层：API、模型、仓库实现
├── domain/            # 领域层：实体、用例、仓库接口
├── presentation/      # 展示层：页面、Widget、Bloc
└── di/                # 依赖注入配置

android/app/src/main/res/
├── mipmap-mdpi/       # 48dp   图标
├── mipmap-hdpi/       # 72dp   图标
├── mipmap-xhdpi/      # 96dp   图标
├── mipmap-xxhdpi/     # 144dp  图标
├── mipmap-xxxhdpi/    # 192dp  图标
├── mipmap-anydpi-v26/ # Android 8.0+ Adaptive Icon 配置
├── drawable/          # 启动页背景
└── values/colors.xml  # 颜色资源
```

## App 图标

自定义霓虹赛博朋克风格图标，包含 K 线蜡烛图元素。

图标更新方式：

```bash
# 1. 替换源像素图
#    编辑 /tmp/stock_app_icon_pixel.png（Neon 风格，512x512）

# 2. 运行生成脚本（需要 Pillow）
python3 /tmp/gen_flutter_icons.py

# 3. 提交更新
git add android/app/src/main/res/mipmap-*/
git commit -m "chore: 更新 App 图标为霓虹K线风格"
```

图标设计规范：

- 风格：Neon 赛博朋克（6px 像素块）
- 前景：霓虹绿（#00E676）上涨 K 线 + 霓虹红（#FF1744）下跌 K 线
- 背景：深蓝（#0D1B2A）
- 格式：PNG（RGBA），各分辨率（mdpi~xxxhdpi）+ Adaptive Icon 前景/背景层
- 适用：Android 5.0+（legacy 图标）+ Android 8.0+（Adaptive Icon）

## 贡献指南

1. 从 `master` 创建功能分支：`git checkout -b feature/xxx`
2. 提交代码并 Push
3. 创建 Pull Request 到 `master`

## 许可证

[待补充]
