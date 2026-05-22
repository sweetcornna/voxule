# voxlue agent 代理

voxlue v1 唯一自建服务端：一个极薄、无状态、无数据库的 Cloudflare Worker。
持有大模型 API key（作为 Worker secret），把设备端的脱敏摘要转发给大模型。
**设备端永不内嵌 key。**

## 本地开发

```bash
cd backend/agent-proxy
npm install
# 本地开发时把 key 放进 .dev.vars（已被 .gitignore，绝不入库）：
echo 'MODEL_API_KEY = "你的key"' > .dev.vars
npm run dev          # 本地起在 http://localhost:8787
npm run typecheck    # 类型检查
```

## 部署步骤

1. 安装并登录 Cloudflare：

   ```bash
   npm install
   npx wrangler login
   ```

2. **把大模型 API key 设为 secret**（不写进任何文件、不入代码库）：

   ```bash
   npx wrangler secret put MODEL_API_KEY
   # 终端会提示粘贴 key，输入后回车 —— key 加密存于 Cloudflare，代码与仓库都看不到它。
   ```

3. 部署：

   ```bash
   npm run deploy
   ```

   部署成功后终端打印 Worker 地址，形如
   `https://voxlue-agent-proxy.<你的子域>.workers.dev`。

4. 把该地址填进 App 端 `voxuleApp.agentProxyURL`
   （计划 06 Task 9 的依赖装配点）。

## 切换大模型

`wrangler.toml` 的 `[vars]` 里改 `MODEL_ENDPOINT` 与 `MODEL_NAME` 即可
（默认 Anthropic Messages API）。换 OpenAI 时同时改 `src/index.ts` 里的
请求头与回复解析。key 始终走 `wrangler secret put`，不进 vars。

## 合规边界

- 代理只转发，不落库、不记请求正文。
- 越过网络边界的只有抽象 `StateDigest` + 非敏感胶囊元数据 —— 原始健康数据
  在设备端 `SignalDistiller` 就被拦下，永不到达此服务。
