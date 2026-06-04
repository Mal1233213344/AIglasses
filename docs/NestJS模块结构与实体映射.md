# NestJS 模块结构与实体映射（第一版）

## 1. 技术选型结论

后端框架采用：

- `NestJS`
- `TypeORM`
- `PostgreSQL`
- `Redis`
- `对象存储`

本次骨架重点解决两件事：

1. 按调用方与业务域拆清模块边界
2. 按数据库表一对一映射核心实体

## 2. 当前目录结构

```text
services/api-server/
  package.json
  src/
    app.module.ts
    main.ts
    common/
      entities/
        created-at.entity.ts
        timestamped.entity.ts
      enums/
        domain.enums.ts
    database/
      database.module.ts
      typeorm.config.ts
    modules/
      app-auth/
      app-profile/
      app-devices/
      app-learning/
      app-content/
      app-support/
      device-bridge/
      admin-auth/
      admin-content/
      admin-devices/
      admin-users/
      admin-system/
      shared-health/
```

## 3. 模块划分原则

### 3.1 面向 APP 的模块

- `app-auth`：验证码登录、协议同意、登录态
- `app-profile`：孩子资料、个人基础信息
- `app-devices`：设备绑定、状态、策略、远程指令、OTA 入口
- `app-learning`：学习汇总、生词、跟读、报告、打卡
- `app-content`：词库、音频内容、固件包查询
- `app-support`：工单、日志上传、推送注册

### 3.2 面向设备的桥接模块

- `device-bridge`：设备状态上报、待执行指令拉取、学习数据上报、OTA 检查

### 3.3 面向后台的模块

- `admin-auth`：后台账号、登录、权限入口
- `admin-content`：内容包、固件包、发布任务
- `admin-devices`：设备列表、设备监控、解绑、升级任务查看
- `admin-users`：用户、学习数据、工单处理
- `admin-system`：系统配置、功能开关、审计日志、导出任务

### 3.4 公共模块

- `database`：数据库连接
- `shared-health`：健康检查、公共 readiness/liveness 接口
- `common`：公共实体基类、常量、枚举、装饰器

## 4. 为什么这样拆

这样拆的好处是：

- APP、设备、后台三种调用方边界非常清晰
- 后续写 controller 时可以直接和 OpenAPI tag 对齐
- service 依赖更容易控制，避免一个“大而全”的业务模块
- 团队并行开发时，设备联调、后台运营、APP 业务可以分线推进

## 5. 实体归属映射

### `app-auth`

- `UserEntity` -> `users`
- `UserAgreementAcceptanceEntity` -> `user_agreement_acceptances`
- `UserSessionEntity` -> `user_sessions`

### `app-profile`

- `ChildProfileEntity` -> `child_profiles`

### `app-devices`

- `DeviceEntity` -> `devices`
- `DeviceBindingEntity` -> `device_bindings`
- `DeviceStatusSnapshotEntity` -> `device_status_snapshots`
- `DevicePolicyEntity` -> `device_policies`
- `DeviceCommandEntity` -> `device_commands`

### `app-learning`

- `LearningDailyStatEntity` -> `learning_daily_stats`
- `LearningWordRecordEntity` -> `learning_word_records`
- `ReadingPracticeRecordEntity` -> `reading_practice_records`

### `app-content`

- `ContentPackageEntity` -> `content_packages`
- `FirmwarePackageEntity` -> `firmware_packages`
- `FirmwareUpgradeTaskEntity` -> `firmware_upgrade_tasks`

### `app-support`

- `FeedbackTicketEntity` -> `feedback_tickets`

### `admin-auth`

- `AdminUserEntity` -> `admin_users`

### `admin-system`

- `AuditLogEntity` -> `audit_logs`
- `SystemConfigEntity` -> `system_configs`

## 6. 模块依赖建议

推荐依赖方向：

- `app-profile` 依赖 `app-auth`
- `app-devices` 依赖 `app-auth`
- `app-learning` 依赖 `app-auth` 与 `app-devices`
- `app-content` 依赖 `admin-auth` 仅做实体关联
- `app-support` 依赖 `app-auth`、`app-devices`、`admin-auth`
- `device-bridge` 聚合 `app-devices`、`app-learning`、`app-content`
- `admin-content` 复用 `app-content`
- `admin-devices` 复用 `app-devices` 与 `app-content`
- `admin-users` 复用 `app-auth`、`app-learning`、`app-support`
- `admin-system` 独立维护系统配置与审计

规则建议：

- controller 只放在调用方所属模块里
- repository 只操作当前模块归属实体
- 跨模块查询优先调用 service，不直接跨模块写 repository

## 7. Controller / Service 继续拆分建议

如果下一步开始真正写接口，我建议每个模块继续拆成：

- `controllers/`
- `services/`
- `dto/`
- `entities/`
- `repositories/` 可选

例如 `app-devices`：

- `app-devices.controller.ts`：设备列表、绑定、切换、解绑
- `device-status.controller.ts`：状态查询
- `device-policy.controller.ts`：策略查询与更新
- `device-command.controller.ts`：即时指令与离线指令查询
- `device-ota.controller.ts`：升级检查、升级任务
- `device.service.ts`
- `device-policy.service.ts`
- `device-command.service.ts`
- `device-ota.service.ts`

## 8. 第一阶段建议先写哪些 Service

优先级最高：

1. `AuthService`
2. `DeviceBindingService`
3. `DeviceStatusService`
4. `DevicePolicyService`
5. `DeviceCommandService`
6. `LearningSummaryService`
7. `ContentCatalogService`
8. `FirmwareUpgradeService`
9. `FeedbackTicketService`
10. `SystemConfigService`

## 9. 当前骨架的定位

当前已经完成：

- `NestJS` 项目骨架
- 根模块与数据库模块
- 一级业务模块
- 核心表对应的 `TypeORM Entity`

当前还没有做：

- controller
- dto
- service
- repository 自定义封装
- 鉴权守卫
- Redis 接入
- 文件上传与对象存储客户端
- 真实迁移脚本与 seed 数据

## 10. 下一步最值得继续做的内容

我建议直接继续下面两项之一：

1. 生成 `controller + service + dto` 骨架，把 OpenAPI 里的关键接口先铺出来
2. 生成 `TypeORM migration` 风格的初始迁移目录和命名规范

## 11. 已补齐的主链路代码骨架

这次已经新增以下代码入口：

### `app-auth`

- `controllers/app-auth.controller.ts`
- `services/app-auth.service.ts`
- `dto/send-sms-code.dto.ts`
- `dto/app-login.dto.ts`
- `dto/request-account-deletion.dto.ts`
- `dto/accept-agreements.dto.ts`

已对齐接口：

- `POST /app/v1/auth/sms-code`
- `POST /app/v1/auth/login`
- `POST /app/v1/auth/logout`
- `POST /app/v1/auth/account-deletion`
- `GET /app/v1/users/me`
- `POST /app/v1/users/me/agreements`

### `app-devices`

- `controllers/app-devices.controller.ts`
- `services/app-devices.service.ts`
- `dto/bind-device.dto.ts`
- `dto/switch-current-device.dto.ts`
- `dto/update-device-policy.dto.ts`
- `dto/create-device-command.dto.ts`
- `dto/create-ota-task.dto.ts`

已对齐接口：

- `GET /app/v1/devices`
- `POST /app/v1/devices/bind`
- `PUT /app/v1/devices/current`
- `POST /app/v1/devices/:deviceId/unbind`
- `GET /app/v1/devices/:deviceId/status`
- `GET /app/v1/devices/:deviceId/policies`
- `PUT /app/v1/devices/:deviceId/policies`
- `POST /app/v1/devices/:deviceId/commands`
- `GET /app/v1/devices/:deviceId/commands/:commandId`
- `GET /app/v1/devices/:deviceId/ota/check`
- `POST /app/v1/devices/:deviceId/ota/tasks`
- `GET /app/v1/devices/:deviceId/ota/tasks/:taskId`

## 12. 当前骨架状态说明

当前 controller 和 service 采用的是“可编排占位实现”：

- 方法签名和接口路径已经落好
- DTO 校验规则已补基础版本
- repository 注入已就位
- 返回值里保留了 `TODO` 提示，方便后续补真实业务逻辑

这意味着现在最适合继续写的是：

1. 接入鉴权守卫，替换 controller 里的临时 userId
2. 实现 `AppAuthService` 的真实登录流程
3. 实现 `AppDevicesService` 的绑定事务、策略更新、离线指令入队、OTA 检查

## 13. 开发环境鉴权约定

当前为了尽快打通主链路，先接入了一个简化版鉴权方案：

- 受保护接口需要携带请求头 `x-user-id`
- `POST /app/v1/auth/sms-code`
- `POST /app/v1/auth/login`

这两个接口被标记为公开接口，不需要 `x-user-id`

新增基础设施：

- `src/common/guards/app-auth.guard.ts`
- `src/common/decorators/public.decorator.ts`
- `src/common/decorators/current-user-id.decorator.ts`
- `src/common/interceptors/response-envelope.interceptor.ts`
- `src/common/filters/http-exception.filter.ts`

说明：

- 当前不是正式 JWT 鉴权，只是为了尽快让 service 能走真实数据库逻辑。
- 后续接入正式登录态时，可以保留 `CurrentUserId` 装饰器，替换 `AppAuthGuard` 的取值来源即可。

## 14. 已从占位改成真实写库的能力

`AppDevicesService` 现在已经不是纯 TODO 占位，已实现基础数据库写操作：

- 绑定设备时自动创建或更新设备主记录
- 绑定设备时回收同设备旧控制权并创建新绑定记录
- 自动设置当前用户的 `current_device_id`
- 首次绑定时自动初始化默认设备策略
- 支持切换当前设备
- 支持解绑当前设备并自动回退到其他已绑定设备
- 支持策略更新并递增 `versionNo`
- 支持创建设备指令记录
- 支持 OTA 检查与 OTA 任务入库

仍然待补：

- Redis 指令队列
- 真正的 JWT/Refresh Token 鉴权
- 短信验证码校验
- 设备在线状态更严格校验
- OTA 版本比较的完整语义化实现
- 设备绑定事务中的并发冲突保护

## 15. 登录态闭环现状

当前 `app-auth` 已经从占位推进到“简化可用版”：

- `POST /app/v1/auth/sms-code`
  - 开发环境返回 `devCode`
- `POST /app/v1/auth/login`
  - 使用开发验证码登录
  - 自动创建用户
  - 自动创建 `user_sessions`
  - 返回 `accessToken`、`refreshToken`
- `POST /app/v1/auth/logout`
  - 根据当前 access token 对应 session 做撤销
- `GET /app/v1/users/me`
  - 通过 bearer token 获取当前用户
- `POST /app/v1/users/me/agreements`
  - 持久化协议同意记录

### 当前 bearer token 调用方式

除公开接口外，其余 APP 接口需要携带：

```http
Authorization: Bearer <accessToken>
```

公开接口仍然只有：

- `POST /app/v1/auth/sms-code`
- `POST /app/v1/auth/login`

### 当前实现说明

- 使用自定义签名 token 服务 `src/common/services/token.service.ts`
- 暂未接入标准 JWT 库，目的是先在不安装额外依赖的前提下打通认证闭环
- `refreshToken` 已生成并存 hash，但还没有开放刷新接口
- 验证码仍是开发态简化实现，默认走 `APP_AUTH_DEV_CODE` 或 `123456`

### 下一步最值得继续做的认证工作

1. 增加 `POST /app/v1/auth/refresh-token`
2. 把 `sendSmsCode/login` 从开发验证码替换成真实短信验证码缓存校验
3. 增加正式的密码/设备风控与会话并发控制

## 16. 新增 refresh-token 与 device-bridge 入口

### 新增认证接口

- `POST /app/v1/auth/refresh-token`

用途：

- 使用 `refreshToken` 换取新的 `accessToken` 和 `refreshToken`
- 会校验 refresh token 签名、session 归属、session 是否撤销、refresh token hash 是否匹配

### 新增设备联调接口

- `POST /device/v1/status-reports`
- `POST /device/v1/commands/pull`
- `POST /device/v1/commands/:commandId/result`
- `POST /device/v1/learning-sync`
- `POST /device/v1/ota/check`
- `POST /device/v1/ota/tasks/:taskId/progress`

### device-bridge 当前已实现能力

- 设备状态上报后写入 `devices` 与 `device_status_snapshots`
- 设备可拉取 `queued` 状态的待执行指令
- 设备可回传指令执行结果并更新指令状态
- 设备可批量上报学习统计、生词记录、跟读记录
- 设备可主动检查 OTA 更新
- 设备可上报 OTA 任务进度与完成状态

### 当前仍是简化实现的点

- `device-bridge` 暂未接入设备级 token 校验
- 指令拉取还没做 ACK 游标与批量确认机制
- OTA 检查还没接灰度发布策略
- 没有照片同步、图传、对讲链路

## 17. 本轮精修说明

本轮重点修复了两个会影响真实运行的问题：

- `AppDevicesModule` 已补注册 `UserEntity`，避免 `AppDevicesService` 的仓储注入缺失
- `device-bridge` 的学习数据上报不再使用临时 `userId fallback`

现在 `syncLearningData` 会：

- 先根据 `device_id` 查询当前有效控制绑定
- 从真实绑定关系里解析 `userId`
- 若当前设备没有有效控制绑定，则直接报错，不再把数据写给错误用户

这意味着设备学习数据链路已经比之前安全很多，更适合进入联调阶段。

### 当前仍需注意

- 还没有做编译级验证
- 指令拉取仍未实现 ACK 游标与过期清理
- 登录链仍是开发验证码模式


## 18. 新增 app-learning 查询接口

家长端现在已经可以查询学习数据：

- `GET /app/v1/learning/summary`
- `GET /app/v1/learning/words`
- `GET /app/v1/learning/practices`

当前行为：

- 自动按当前登录用户过滤设备归属
- 若传 `deviceId`，会校验该设备是否属于当前用户
- `summary` 支持 `day/week/month`
- `words/practices` 支持分页

## 19. device-bridge 设备鉴权约定

`device-bridge` 现在已经加了设备侧鉴权守卫。

调用设备接口时需要带：

```http
x-device-token: <DEVICE_BRIDGE_TOKEN>
```

当前默认开发值：

- `dev-device-token`

后续建议：

- 从全局共享 token 升级成按设备独立 token
- 将 token 与 `devices` 表或独立 `device_credentials` 表绑定

## 20. 当前可联调的最小闭环

现在已经具备一个比较完整的最小联调闭环：

1. `POST /app/v1/auth/sms-code`
2. `POST /app/v1/auth/login`
3. APP 使用 `Authorization: Bearer <accessToken>` 调用设备绑定与学习查询接口
4. 设备使用 `x-device-token` 调用 `device-bridge` 接口上报状态、拉指令、回执行结果、上报学习数据
5. 家长端通过 `GET /app/v1/learning/*` 查询学习结果


## 21. 新增学习报告接口

`app-learning` 现在已经补上学习报告能力：

- `POST /app/v1/learning/reports`
- `GET /app/v1/learning/reports/:reportId`

新增内容：

- `entities/learning-report.entity.ts` -> `learning_reports`
- `dto/create-learning-report.dto.ts`
- `AppLearningService.createLearningReport`
- `AppLearningService.getLearningReport`

当前生成逻辑：

- 先校验 `deviceId` 是否属于当前登录用户
- 按 `daily / weekly / monthly` 计算统计窗口
- 从 `learning_daily_stats` 聚合学习时长、识词数、跟读次数、活跃天数等指标
- 基于简单规则输出 `weakTags`
- 若同设备、同报告类型、同报告日期已存在报告，则覆盖更新；否则新建

当前说明：

- 这是第一版可联调实现，适合先打通家长端“查看学习报告”链路
- `summaryText` 与 `weakTags` 目前采用规则生成，不是大模型生成
- 如果后续要做更强的 AI 讲评，可以在这个实体结构上继续扩展

## 22. 当前值得优先继续的收尾项

如果继续往生产可用方向推进，建议优先处理：

1. 实际执行 `nest build` 做编译级修复
2. 将 `device-bridge` 的共享 token 升级为按设备 token
3. 为学习报告补后台重算入口与定时任务
4. 为指令下发补 ACK 游标、过期清理与 Redis 队列
