# OTA 升级协议规范

## 1. 概述

本协议定义了儿童 AI 英语眼镜的固件在线升级 (OTA) 流程。

## 2. 升级流程图

1. **检测**: APP 调用 `/app/v1/devices/{deviceId}/ota/check`。
2. **任务创建**: APP 调用 `/app/v1/devices/{deviceId}/ota/tasks` 创建升级任务。
3. **指令下发**: 后端通过 `DeviceBridge` 将 `OTA_START` 指令入队。
4. **拉取**: 设备联网后拉取 `OTA_START` 指令，包含 `packageUrl` 和 `sha256`。
5. **下载与校验**: 设备下载固件包并校验完整性。
6. **进度上报**: 设备定时调用 `/device/v1/ota/tasks/{taskId}/progress`。
7. **安装与重启**: 设备安装固件并自动重启。
8. **验证**: 重启后上报新版本号，任务标记为 `SUCCESS`。

## 3. 固件包清单 (ota-manifest-schema.json)

```json
{
  "version": "v1.2.5",
  "buildDate": "2026-03-30",
  "minRequiredVersion": "v1.0.0",
  "packageUrl": "https://oss.example.com/fw/v1.2.5.zip",
  "sha256": "a1b2c3d4e5f6...",
  "size": 12582912,
  "changelog": "1. 优化 AI 响应速度\n2. 修复蓝牙连接稳定性问题",
  "isForceUpdate": false,
  "supportedModels": ["STD", "PRO", "MAX"]
}
```

## 4. 升级前置检查项 (Pre-flight Check)

设备在执行升级前必须满足以下条件：
- **电量**: >= 30% (若连接电源则 >= 10%)。
- **存储**: 剩余空间 > 固件包大小的 2 倍。
- **网络**: WiFi 信号强度 (RSSI) > -70dBm。

## 5. 异常处理与回滚

- **校验失败**: 立即终止，清理下载文件，并上报 `ERROR_CHECKSUM_MISMATCH`。
- **断电中断**: 若在写入 Flash 时断电，设备应支持 A/B 分区备份，自动回滚至旧版本分区。
- **超时**: 若 30 分钟未上报进度，后端自动将任务标记为 `TIMEOUT_FAILED`。
