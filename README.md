# PinSeeker Strategy - 智能高尔夫策略码本 ⛳️

PinSeeker 是一款基于 Flutter 开发的现代化高尔夫电子码本 (Web App)。它不同于传统的测距仪，它结合了 **Trackman 击球数据**与**卫星地图**，通过可视化“落点散布椭圆”和“策略连线”，帮助业余高手制定职业级的击球策略。

## ✨ 核心功能 (Features)

### 1. 🛰️ 高清卫星球场 (Satellite Mapping)
- 集成 Google Hybrid 高清卫星地图。
- **Heads-Up 视角：** 地图自动根据球洞走向旋转，发球台在下，果岭在上，符合直觉。
- **当前球场：** 德国 Duvenhof Golf Club - Hole 1 (Par 4)。

### 2. 📊 数据驱动的球杆选择 (Data-Driven Club Selector)
- 内置完整的球杆数据库 (Driver 至 58° 挖起杆)。
- **真实数据模型：** 基于 Trackman/Launch Monitor 的击球数据（落点距离 + 左右/前后散布）。
- **动态椭圆渲染：** 
  - 选择 Driver 时显示巨大的散布椭圆（高风险）。
  - 选择 Wedge 时显示精准的小椭圆（低风险）。

### 3. 🧠 策略推演引擎 (Strategy Engine)
- **可视化落点：** 蓝色半透明椭圆代表 90% 的球落点概率范围。
- **策略连线 (Strategy Line)：**
  - 实线：当前一杆的飞行轨迹。
  - 虚线：预测落点到果岭中心的剩余路径。
- **实时计算：** 动态显示 "Next Shot" (下一杆剩余距离)，辅助判断是激进进攻还是安全过渡。

### 4. 👆 上帝之手交互 (God Mode Interaction)
- **点击即瞄准：** 点击地图上任意一点（如避开沙坑的安全区），系统自动调整瞄准方向。
- **滑块微调：** 支持通过底部滑块精确调整瞄准角度 (Aim Angle)。

---

## 🛠 技术栈 (Tech Stack)
- **Framework:** Flutter (Dart)
- **Map Engine:** `flutter_map` + `latlong2`
- **Math:** `vector_math` (用于计算椭圆几何点集)
- **Platform:** Flutter Web (HTML Renderer)

---

## 🚀 部署与运行 (Deployment)

### 本地开发环境 (Windows + iPad 联调)

1. **环境准备：** 
   确保已安装 Flutter SDK 并配置好环境变量。

2. **安装依赖：**
   ```bash
   flutter pub get


   启动 Web 服务器：
为了在局域网设备（如 iPad/iPhone）上访问，需使用以下命令启动：
code
Bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 --web-renderer html
手机访问：
确保手机与电脑在同一 Wi-Fi 下。
获取电脑 IP 地址 (cmd -> ipconfig)。
手机浏览器访问：http://[电脑IP]:8080
生产环境部署 (推荐)
本项目支持部署为静态网站 (Static Web App)。推荐使用 Vercel 或 GitHub Pages 进行免费托管。
code
Bash
# 编译命令
flutter build web --web-renderer html --release