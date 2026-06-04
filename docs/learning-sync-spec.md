# 学习数据同步协议规范

## 1. 概述

本协议定义了儿童 AI 英语眼镜设备向云端上报学习行为数据的规范。

## 2. 数据结构定义

### 2.1 学习时长统计 (learning_daily_stats)

- `deviceId`: `uuid`
- `date`: `date` (YYYY-MM-DD)
- `studyMinutes`: `number`
- `recognizedWordCount`: `number`
- `followReadCount`: `number`
- `averagePracticeScore`: `number` (0-100)

### 2.2 识别单词记录 (learning_word_records)

- `id`: `uuid`
- `deviceId`: `uuid`
- `word`: `string`
- `translation`: `string`
- `phonetic`: `string`
- `imageBase64`: `string` (optional, for visual learning)
- `capturedAt`: `timestamptz`

### 2.3 跟读练习记录 (reading_practice_records)

- `id`: `uuid`
- `deviceId`: `uuid`
- `text`: `string` (跟读原文)
- `audioUrl`: `string` (音频文件在 OSS 中的路径)
- `score`: `number` (0-100)
- `fluency`: `number` (0-100)
- `accuracy`: `number` (0-100)
- `practicedAt`: `timestamptz`

## 3. 同步机制 (Device -> Backend)

1. **增量同步**: 设备维护一个本地同步游标 (cursor/timestamp)，仅上报未同步的数据。
2. **批量上报**: 建议每 5 分钟或累积 10 条数据后批量调用 `/device/v1/learning-sync`。
3. **离线缓存**: 设备应至少缓存 7 天的学习数据。
4. **去重规则**: 后端根据 `deviceId` + `capturedAt` 或 `idempotencyKey` 进行去重。

## 4. 接口细节 (POST /device/v1/learning-sync)

```json
{
  "deviceId": "uuid",
  "batchId": "uuid",
  "records": [
    {
      "type": "WORD_RECOGNITION",
      "data": { "word": "Apple", "translation": "苹果", "capturedAt": "2026-03-30T10:00:00Z" }
    },
    {
      "type": "READING_PRACTICE",
      "data": { "text": "Hello world", "score": 95, "practicedAt": "2026-03-30T10:05:00Z" }
    }
  ]
}
```

## 5. 学习报告生成逻辑

1. **日报告**: 每日凌晨 1:00 由后端定时任务自动汇总前一天的统计数据。
2. **AI 寄语**: 调用 LLM (如通义千问) 为每个孩子生成一段个性化的鼓励性评价。
3. **推送**: 报告生成后，后端向家长端 APP 发送推送通知。
