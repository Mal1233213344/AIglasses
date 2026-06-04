# BLE GATT 协议规范

## 1. 概述

本协议定义了家长端 APP 与儿童 AI 英语眼镜硬件设备之间的蓝牙低功耗 (BLE) 通信规范。

## 2. 角色定义

- **Server (Peripheral)**: AI 英语眼镜
- **Client (Central)**: 家长端 APP (Flutter)

## 3. 连接参数

- **MTU**: 建议 247 bytes (最小 23 bytes)
- **广播名规则**: `AI-Glasses-XXXX` (XXXX 为 MAC 地址后四位)
- **广播内容**: 包含 Service UUID `0000FF01-0000-1000-8000-00805F9B34FB`

## 4. Service 与 Characteristic 定义

主服务 UUID: `0000FF01-0000-1000-8000-00805F9B34FB`

| 特征名 | UUID | 属性 | 说明 |
| :--- | :--- | :--- | :--- |
| **Command Write** | `0000FF02-...` | Write | APP 下发指令 (JSON/Protobuf) |
| **Status Notify** | `0000FF03-...` | Notify | 设备状态主动上报 |
| **Data Transfer** | `0000FF04-...` | Write/Notify | 大块数据传输 (分片) |
| **Auth** | `0000FF05-...` | Read/Write | 设备身份验证与握手 |

## 5. 数据帧格式

所有指令采用 JSON 格式封装（生产环境可切换为 Protobuf）：

```json
{
  "seq": 1,
  "cmd": "SET_VOLUME",
  "data": {
    "value": 85
  },
  "timestamp": 1711785600
}
```

## 6. 核心指令集

### 6.1 设备管控 (APP -> Device)
- `LOCK_SCREEN`: 立即锁定/解锁屏幕
- `SET_VOLUME`: 设置音量
- `SET_TIME_LIMIT`: 设置使用时长限制
- `REMOTE_SHUTDOWN`: 远程关机
- `OTA_START`: 触发 OTA 升级

### 6.2 状态同步 (Device -> APP)
- `STATUS_REPORT`: 定时上报电量、网络、当前模式
- `EVENT_NOTIFY`: 关键事件（低电量、同步完成、异常错误）

## 7. 安全与配对

1. 广播包含加密后的 SN 摘要。
2. 首次绑定需在眼镜端确认（物理按键或语音确认）。
3. 通信链路采用 AES-128 加密。
