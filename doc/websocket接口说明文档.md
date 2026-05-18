# 1. 吸乳会话小结

## 接口信息

| 属性 | 说明 |
|------|------|
| **接口类型** | WebSocket |
| **接口地址** | `ws://{host}/v1/pump/session-summary` |
| **功能描述** | 实时生成单次吸乳会话的小结报告 |

---

## 请求参数

### 必需参数

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `user_id` | string | 用户唯一标识，不能为空 |
| `conversation_id` | string | 会话ID，用于上下文关联 |

### 可选参数

| 参数名 | 别名 | 类型 | 说明 | 默认值 |
|--------|------|------|------|--------|
| `ended_at` | `endedAt`, `at` | string | 结束时间（ISO 8601格式） | 当前时间 |
| `started_at` | `startedAt` | string | 开始时间（ISO 8601格式） | - |
| `end_reason` | `reason` | string | 结束原因（见下表） | `"unknown"` |
| `process_all` | `processAll` | number | 整体吸乳进程百分比（0-100） | 从设备数据计算 |
| `total_milk_ml` | `totalMilkMl` | number | 总奶量（ml） | 从设备数据计算 |
| `event_id` | `eventId`, `idempotency_key` | string | 事件唯一标识 | 自动生成 |

### 结束原因枚举值

| 值 | 显示文本 |
|----|----------|
| `user-confirm` | 手动确认结束 |
| `device-offline-ended-single` | 检测到设备离线后结束 |
| `device-offline-ended-both` | 两侧设备均离线后自动结束 |
| `pause-timeout-ended` | 暂停超时后自动结束 |
| 其他 | 本次吸奶已结束 |

### 设备数据对象（left/right）

| 参数名 | 别名 | 类型 | 说明 |
|--------|------|------|------|
| `connected` | - | boolean | 是否连接 |
| `milk_ml` | `milkMl`, `final_milk_ml`, `finalMilkMl`, `milk` | number | 该侧奶量（ml） |
| `process` | - | number | 该侧进程百分比 |
| `mode` | `pumpMode` | string | 吸乳模式 |
| `level` | `gear` | number | 档位 |
| `duration_seconds` | `duration` | number | 持续时长（秒） |
| `has_milk` | `hasMilk` | boolean | 是否有奶 |
| `has_letdown` | `hasLetdown` | boolean | 是否有奶阵 |

---

## 返回值结构

### 成功响应（status: 200）

```json
{
  "status": 200,
  "message": "success",
  "data": {
    "error": 0,
    "session": {
      "event_id": "pump-summary-20240101103000",
      "ended_at": "2024-01-01T10:30:00+08:00",
      "end_reason": "user-confirm",
      "duration_seconds": 300,
      "total_milk_ml": 150.8,
      "left_milk_ml": 80.5,
      "right_milk_ml": 70.3,
      "process_all": 92.8
    },
    "chat_message": {
      "id": "pump-summary-20240101103000",
      "role": "mai",
      "content": "手动确认结束，用时 5 分钟，总奶量约 151 ml。左侧 80 ml，右侧 70 ml，左右比较接近。本次吸奶进程完成度较高，可以先休息、补水。如出现发热、明显红肿、剧痛或硬块加重，建议及时寻求专业帮助。",
      "timestamp": "10:30",
      "cardType": "report",
      "cardData": {
        "kind": "pump-session-summary",
        "event_id": "pump-summary-20240101103000"
      }
    },
    "context": {
      "appended": true,
      "target": "local_runtime"
    }
  }
}
```

### 失败响应（status: 400）

```json
{
  "status": 400,
  "message": "user_id is required",
  "data": {
    "error": -1,
    "message": "user_id is required"
  }
}
```

---

## 数据计算优先级

### 时长计算

1. 优先使用 `duration_seconds` / `durationSeconds`
2. 其次使用左右侧设备的 `duration_seconds`
3. 最后通过 `started_at` 和 `ended_at` 计算

### 总奶量计算

1. 优先使用 `total_milk_ml` / `totalMilkMl`
2. 其次通过左右侧奶量相加计算

### 进程计算

1. 优先使用 `process_all` / `processAll`
2. 其次通过左右侧进程平均值计算

---

## 请求示例

```json
{
  "user_id": "user_123456",
  "conversation_id": "conv_abcdef",
  "ended_at": "2024-01-01T10:30:00Z",
  "started_at": "2024-01-01T10:25:00Z",
  "end_reason": "user-confirm",
  "left": {
    "connected": true,
    "milk_ml": 80.5,
    "process": 95.5,
    "mode": "expression",
    "level": 5,
    "duration_seconds": 300
  },
  "right": {
    "connected": true,
    "milk_ml": 70.3,
    "process": 90.0,
    "mode": "expression",
    "level": 4,
    "duration_seconds": 300
  }
}
```

---

## 错误码说明

| 错误码 | 错误信息 | 原因 |
|--------|----------|------|
| -1 | `invalid request body` | 请求体不是有效的 JSON |
| -1 | `conversation_id is required` | 缺少会话ID |
| -1 | `missing_user_id` | 缺少用户ID |
| -1 | `failed` | 其他处理失败 |