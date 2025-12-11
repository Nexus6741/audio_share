# audio_share

一个局域网音频共享的 Flutter 跨平台样例。

## 功能概述
- 使用 UDP 广播发现同一局域网内的其他设备，在状态变更时即时广播并自动剔除掉线节点，设备名称会自动读取主机名用于识别。
- 选择一台设备作为接收端，其余设备可以将麦克风/系统声音推送到该设备，并可从列表看到哪些设备处于“接收中”，推流时会优先使用对端公布的接收端口，接收端下线时会自动停止推流并提示状态，接收端支持实时音量滑杆与播放状态提示方便监听。
- Flutter UI 支持 Android、Windows、macOS，底层使用 `dart:io` 套接字完成传输，接收端通过流式播放避免重设音源带来的卡顿。

> ⚠️ 本仓库提供的是最小化可运行示例，并未针对生产环境做完备的安全、带宽控制和系统音频捕获适配，请按需扩展。

## 目录
```
lib/
  main.dart              # 入口，挂载 Provider
  screens/home_screen.dart  # UI：设备列表、开启接收、选择接收端
  services/
    discovery_service.dart  # UDP 广播发现
    audio_sender.dart       # 录音并通过 UDP 发送 PCM 数据
    audio_receiver.dart     # 接收 UDP 数据并播放
    session_state.dart      # 全局状态与角色切换
  widgets/device_card.dart  # 设备卡片组件
pubspec.yaml            # 依赖声明
```

## 运行步骤
1. 安装 Flutter 3.0+，并确保 Windows/macOS/Android 的桌面/移动端编译链完整。
2. `flutter pub get`
3. 将应用同时运行在局域网内的多台设备上：
   - 在希望作为 **接收端** 的设备上点击“开启接收模式”。
   - 在其他设备的列表中选择该接收端，即会开始推流（列表中只可点击处于“接收中”的设备），推流可随时在顶部工具栏停止。

## 技术要点与下一步改进
- **音频采集**：使用 [`record`](https://pub.dev/packages/record) 的 `startStream` 获取 PCM 片段。部分平台需要手动开启麦克风权限，未授权会拒绝推流；系统音频采集可通过平台通道接入原生实现。
- **传输协议**：当前使用 UDP 发送裸 PCM，简单低延迟但无重传；可替换为 WebRTC/QUIC 或 Opus 编码提升抗丢包能力。
- **播放**：`just_audio` 通过流式 `StreamAudioSource` 持续播放收到的 PCM buffer，避免频繁重置音源导致的卡顿，可在生产环境中进一步引入抖动控制。
- **发现**：默认广播端口 `42042`，音频端口 `43210`，可在同一局域网内更改为多播地址减少广播噪声。
