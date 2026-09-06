# 语销镜 · VoiceSale Review

面向销售对话复盘的双端原型：上传一段销售录音（可选），补充行业、通话目标、产品和价值主张，即可得到结构化复盘结果。

项目包含两个客户端：

- **Web**：Vite + React 的复盘工作台，适合本地演示与快速验证。
- **iOS**：SwiftUI 原生客户端，支持账户、云端记录与音频上传流程。

> 当前版本的转写与分析提供方是可运行的模拟实现，用于演示完整流程；并未接入生产可用的 AI 转写或大模型分析服务。

## 功能

- 录入行业、通话目标、产品名称和价值主张
- 选择性上传音频；无音频时也可运行模板演示
- 输出销售对话阶段、能力信号、关键失误、客户画像与下一通话术
- Web 端将复盘历史保存在浏览器 `localStorage`
- iOS 云端模式支持 Supabase 认证、复盘记录和音频对象存储

## 项目结构

```text
src/                         # Web 客户端
  App.tsx                    # 主界面与交互
  orchestrator.ts            # 复盘流程编排
  providers/                 # 模拟转写与分析提供方
VoiceSaleiOS/                # SwiftUI iOS 客户端
supabase/
  migrations/                # 数据库与 Storage 迁移
  schema.sql                 # 合并后的数据库定义
```

## Web 快速开始

安装依赖并启动开发服务器：

```bash
npm install
npm run dev
```

构建生产包：

```bash
npm run build
```

本地预览构建结果：

```bash
npm run preview
```

### Web 配置

可选环境变量如下：

```bash
VITE_TRANSCRIPTION_PROVIDER=mock
VITE_ANALYSIS_PROVIDER=template
VITE_ENABLE_REAL_AI=false
```

默认值分别为 `mock`、`template` 和 `false`。即使选择 `openai`，当前代码仍会回退到模拟结果；真实 API 调用仅保留了实现位置的注释，不应在前端暴露任何服务端密钥。

## iOS 快速开始

1. 使用 Xcode 打开 [VoiceSaleiOS.xcodeproj](VoiceSaleiOS/VoiceSaleiOS.xcodeproj)。
2. 选择 `VoiceSale` target，并在 iOS 17 或更高版本的模拟器或真机上运行。
3. 创建本机 Supabase 配置（该文件已被 Git 忽略）：

   ```bash
   cp VoiceSaleiOS/Config/Supabase.xcconfig.example VoiceSaleiOS/Config/Supabase.xcconfig
   ```

   在新建文件中填写自己项目的 `SUPABASE_URL` 和 `SUPABASE_ANON_KEY`。请只使用 Supabase 的发布密钥，绝不要填入 `sb_secret_...` 或服务端角色密钥。

4. 在 Supabase Dashboard 的 **Authentication → URL Configuration → Redirect URLs** 中添加：

   ```text
   voicesale://auth-callback
   ```

iOS 的云端模式需要先登录。它会创建通话记录、可选上传音频，并保存复盘结果；当前复盘内容仍由 `MockReviewEngine` 生成。

## Supabase 数据模型

数据库定义位于 `supabase/migrations/`。首次配置时依次应用：

1. `20260503061625_init_voice_sale_schema.sql`
2. `20260503094200_expand_call_audio_mime_types.sql`

主要资源包括：

- `products`：产品与价值主张
- `calls`：销售通话与处理状态
- `transcript_segments`：逐段转写结果
- `review_results`、`evidence_clips`：复盘结论与证据片段
- `analysis_jobs`：转写与分析任务状态
- `call-audio`：私有音频 Storage bucket（最大 500 MiB）

表和音频对象均启用行级安全策略（RLS）；策略以登录用户和对象路径的首段用户 ID 进行隔离。

## 数据与安全

- 不要提交 `.env`、私钥或服务端角色密钥；仓库已忽略 `.env` 与 `.env.*`。
- 浏览器端配置只能使用可公开的 `VITE_*` 变量，敏感服务端调用应通过受保护的后端完成。
- 真实音频通常包含个人信息。上线前请明确取得授权，并根据业务所在地的隐私与数据保留要求设计流程。

## 当前限制

- Web 端历史记录仅保存在当前浏览器。
- 真实语音转写与 AI 分析尚未接入。
- iOS 云端流程会持久化模拟复盘结果，尚未连接异步 AI 任务执行器。

## 下一步

1. 在受保护的后端接入真实转写和分析服务。
2. 用队列或 Edge Function 执行异步分析任务，并回写 `analysis_jobs`。
3. 为 Web 端添加账户、云端同步与受控音频上传。
