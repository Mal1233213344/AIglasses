# 设备管控指令协议规范

## 1. 概述

本协议定义了家长端 APP 与儿童 AI 英语眼镜之间的控制指令细节。

## 2. 指令基础格式

所有指令均包含以下基础字段：

```json
{
  "commandId": "uuid",
  "type": "control",
  "action": "ACTION_NAME",
  "payload": {},
  "timestamp": 1711785600,
  "expiry": 86400
}
```

## 3. 指令集列表

### 3.1 锁屏/解锁 (SCREEN_LOCK)

控制眼镜屏幕是否可用，通常用于管控孩子的使用时间。

- **Action**: `SET_SCREEN_LOCK`
- **Payload**:
  - `locked`: `boolean`
  - `lockReason`: `string` (optional: 'TIME_LIMIT', 'MANUAL_LOCK')

### 3.2 音量设置 (SET_VOLUME)

设置眼镜的最大允许音量。

- **Action**: `SET_VOLUME_LIMIT`
- **Payload**:
  - `maxVolumeDb`: `number` (建议范围: 40-85 dB)
  - `lockVolumeButton`: `boolean` (锁定硬件音量按键)

### 3.3 时长限制 (SET_TIME_LIMIT)

设置单次或每日使用时长。

- **Action**: `SET_TIME_LIMIT`
- **Payload**:
  - `singleSessionMinutes`: `number`
  - `dailyTotalMinutes`: `number`
  - `restIntervalMinutes`: `number`

### 3.4 远程开关机/重启 (POWER_CONTROL)

- **Action**: `POWER_CONTROL`
- **Payload**:
  - `action`: `string` ('SHUTDOWN', 'REBOOT')

### 3.5 护眼提醒 (EYE_PROTECTION)

配置眼镜的护眼模式。

- **Action**: `SET_EYE_PROTECTION`
- **Payload**:
  - `enabled`: `boolean`
  - `remindIntervalMinutes`: `number`

### 3.6 省电模式 (POWER_SAVE)

- **Action**: `SET_POWER_SAVE`
- **Payload**:
  - `enabled`: `boolean`
  - `autoEnterThreshold`: `number` (电量低于此值自动进入，如 15)

## 4. 离线指令处理逻辑

1. **缓存**: 离线指令由后端 `Redis` 缓存，并在 `PostgreSQL` 中持久化记录。
2. **时效**: 指令默认 24 小时有效，过期自动废弃。
3. **覆盖**: 同类指令以最新下发的为准，旧指令将被标记为 `OVERRIDDEN`。
4. **执行确认**: 设备联网后拉取指令，执行成功后上报 `ACK`，状态变更为 `EXECUTED`。
5. **异常**: 执行失败需上报 `ERROR_CODE`，家长端 APP 可重试。
