# voxlue agent 代理

voxlue v1 唯一自建服务端：一个极薄、无状态、无数据库的 Cloudflare Worker。
持有大模型 API key（作为 Worker secret），把设备端的脱敏摘要转发给大模型。
**设备端永不内嵌 key。**

## 鉴权与边界（D2 / D23）

- **设备鉴权**：每个请求必须带 `Authorization: Bearer <DEVICE_TOKEN>`，
  与 Worker `DEVICE_TOKEN` secret 常数时间比对。缺/错 → `401 {"error":"unauthorized"}`。
  未配 `DEVICE_TOKEN` 时一律拒绝，绝不退化成开放代理。
- **请求正文上限**：> 16 KB → `413`（先看 `Content-Length`，再按实际字节兜底）。
- **CORS**：本代理仅供原生 App 调用，**不发任何 CORS 头、不反射 Origin**。
  浏览器跨域请求因缺 `Access-Control-Allow-Origin` 被拦在客户端 —— 有意为之。
- **错误脱敏**：对客户端一律给笼统错误（`service unavailable` / `unauthorized`），
  绝不回显上游状态码或后端配置；真实细节只 `console.error` 到服务端日志（不落库）。
- **请求体**：设备每轮重发**完整对话历史** `messages: {role, content}[]`，
  代理无状态、原样转发给模型（注入 `SYSTEM_PROMPT` 作为顶层 `system`）。

## 本地开发

```bash
cd backend/agent-proxy
npm install
# 本地开发时把 key 与设备 token 放进 .dev.vars（已被 .gitignore，绝不入库）：
printf 'MODEL_API_KEY = "你的key"\nDEVICE_TOKEN = "本地测试token"\n' > .dev.vars
npm run dev          # 本地起在 http://localhost:8787
npm run typecheck    # 类型检查
```

## 部署步骤

1. 安装并登录 Cloudflare：

   ```bash
   npm install
   npx wrangler login
   ```

2. **把大模型 API key 与设备 token 设为 secret**（不写进任何文件、不入代码库）：

   ```bash
   npx wrangler secret put MODEL_API_KEY
   # 终端会提示粘贴 key，输入后回车 —— key 加密存于 Cloudflare，代码与仓库都看不到它。

   npx wrangler secret put DEVICE_TOKEN
   # 设备鉴权 token —— 设备端必须带 `Authorization: Bearer <DEVICE_TOKEN>` 才能调用。
   # 同一 token 也要装配进 App 端（见下「鉴权契约」）。
   ```

3. 部署：

   ```bash
   npm run deploy
   ```

   部署成功后终端打印 Worker 地址，形如
   `https://voxlue-agent-proxy.<你的子域>.workers.dev`。

4. 把该地址填进 App 端 `voxuleApp.agentProxyURL`，并把 `DEVICE_TOKEN`
   装配进 `voxuleApp.deviceToken`（计划 06 Task 9 的依赖装配点）。

## 鉴权契约（供 App 端装配）

| 项 | 值 |
| --- | --- |
| 请求头 | `Authorization: Bearer <token>` |
| token 来源（设备） | `HTTPRemoteModelClient(deviceToken:)` 注入 → `AgentContainer(deviceToken:)` → `voxuleApp.deviceToken` |
| Worker 校验 | `env.DEVICE_TOKEN` secret，常数时间比对 |
| 二者必须一致 | App 端 token === Worker `DEVICE_TOKEN` secret |

### curl 鉴权自测

```bash
URL="http://localhost:8787"   # 或部署后的 workers.dev 地址
TOKEN="本地测试token"          # 与 .dev.vars / secret 里的 DEVICE_TOKEN 一致

# 1) 缺 token → 401
curl -s -o /dev/null -w '%{http_code}\n' -X POST "$URL" \
  -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"hi"}]}'
# 期望：401

# 2) 错 token → 401
curl -s -o /dev/null -w '%{http_code}\n' -X POST "$URL" \
  -H 'Content-Type: application/json' -H 'Authorization: Bearer wrong' \
  -d '{"messages":[{"role":"user","content":"hi"}]}'
# 期望：401

# 3) 正确 token → 200（再走到模型调用）
curl -s -X POST "$URL" \
  -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" \
  -d '{"messages":[{"role":"user","content":"请决定是否浮现，并按约定 JSON 输出。"}]}'
# 期望：200 + AgentReply JSON
```

## 切换大模型

`wrangler.toml` 的 `[vars]` 里改 `MODEL_ENDPOINT` 与 `MODEL_NAME` 即可
（默认 Anthropic Messages API）。换 OpenAI 时同时改 `src/index.ts` 里的
请求头与回复解析。key 始终走 `wrangler secret put`，不进 vars。

## 合规边界

- 代理只转发，不落库、不记请求正文。
- 越过网络边界的只有抽象 `StateDigest` + 非敏感胶囊元数据 —— 原始健康数据
  在设备端 `SignalDistiller` 就被拦下，永不到达此服务。
