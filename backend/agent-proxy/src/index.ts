/**
 * voxlue agent 代理 —— v1 唯一自建服务端。
 *
 * 设计原则（架构文档 §7）：极薄、无状态、无数据库。
 * 唯一职责：持有大模型 API key（作为 secret），把设备来的
 * { StateDigest + 非敏感上下文 } 转成一次大模型调用，再把模型回复
 * 整形成设备端约定的 AgentReply 返回。设备端永不见 key。
 *
 * 它不存任何用户数据、不记请求正文、不做鉴权之外的状态保持。
 */

export interface Env {
  // 经 `wrangler secret put MODEL_API_KEY` 注入，不入代码库。
  MODEL_API_KEY: string;
  MODEL_ENDPOINT: string;
  MODEL_NAME: string;
}

// ---- 与设备端约定的数据结构（对应 Swift 侧 DTO）----

interface StateDigest {
  tension: 'low' | 'medium' | 'high';
  sleep: 'low' | 'medium' | 'high';
  calmCapsulesAvailable: number;
  daysSinceLastSurfacing: number;
}

interface CapsuleMeta {
  id: string;
  title: string;
  tags: string[];
  placeName: string | null;
}

interface AgentContext {
  candidates: CapsuleMeta[];
  cadence: string;
}

interface ToolCall {
  name: string;
  arguments: Record<string, string>;
}

interface AgentReply {
  toolCalls: ToolCall[];
  finished: boolean;
  surfaceCapsuleID: string | null;
}

interface RequestBody {
  sessionID?: string;
  phase: 'start' | 'continue';
  digest?: StateDigest;
  context?: AgentContext;
  turn?: { toolResults: { name: string; output: string }[]; finished: boolean };
}

// agent 的系统提示词 —— 陪伴定位，始终用安静的陪伴语气、不用任何临床或医疗措辞。
const SYSTEM_PROMPT = `你是 voxlue 的陪伴 agent。voxlue 把环境声做成「声音胶囊」，
情绪锁胶囊由你判断何时「浮现」给用户。

你的角色是一个安静的、旧派的冲洗师，是「陪伴」的存在。
始终用安静的陪伴语气，不用任何临床或医疗措辞。
你不读体征、不打分 —— 你只看到一份抽象摘要（紧绷度/睡眠/可用平静胶囊数/距上次浮现天数）。

根据摘要与候选胶囊元数据，决定是否浮现一枚情绪胶囊、浮现哪枚。
克制：宁可 hold，也不要打扰。距上次浮现太近、或没有合适候选时，就 hold。

只输出一个 JSON 对象，不要任何额外文字，结构：
{ "toolCalls": [ { "name": "surfaceCapsule", "arguments": { "capsuleID": "<id>" } } ],
  "finished": true, "surfaceCapsuleID": "<id 或 null>" }
决定不浮现时：{ "toolCalls": [], "finished": true, "surfaceCapsuleID": null }`;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method !== 'POST') {
      return jsonResponse({ error: 'method not allowed' }, 405);
    }
    if (!env.MODEL_API_KEY) {
      return jsonResponse({ error: 'proxy misconfigured: missing key' }, 500);
    }

    let body: RequestBody;
    try {
      body = (await request.json()) as RequestBody;
    } catch {
      return jsonResponse({ error: 'invalid JSON' }, 400);
    }

    // 把设备来的摘要 + 上下文整形成给大模型的用户消息。
    const userContent =
      body.phase === 'start'
        ? `状态摘要：${JSON.stringify(body.digest)}\n` +
          `候选胶囊：${JSON.stringify(body.context?.candidates ?? [])}\n` +
          `浮现频率档：${body.context?.cadence ?? 'occasionally'}\n` +
          `请决定是否浮现，并按约定 JSON 输出。`
        : `上一轮工具结果：${JSON.stringify(body.turn?.toolResults ?? [])}\n` +
          `请给出最终决定，并按约定 JSON 输出。`;

    // 调大模型（Anthropic Messages API 形态）。key 在此处、且仅在此处使用。
    let modelResponse: Response;
    try {
      modelResponse = await fetch(env.MODEL_ENDPOINT, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': env.MODEL_API_KEY,
          'anthropic-version': '2023-06-01',
        },
        body: JSON.stringify({
          model: env.MODEL_NAME,
          max_tokens: 512,
          system: SYSTEM_PROMPT,
          messages: [{ role: 'user', content: userContent }],
        }),
      });
    } catch {
      return jsonResponse({ error: 'upstream transport failed' }, 502);
    }

    if (!modelResponse.ok) {
      return jsonResponse({ error: `upstream status ${modelResponse.status}` }, 502);
    }

    // 从模型回复里抽出那段 JSON，整形成 AgentReply。
    let reply: AgentReply = { toolCalls: [], finished: true, surfaceCapsuleID: null };
    try {
      const data = (await modelResponse.json()) as {
        content?: { type: string; text?: string }[];
      };
      const text = data.content?.find((c) => c.type === 'text')?.text ?? '';
      const match = text.match(/\{[\s\S]*\}/);
      if (match) {
        const parsed = JSON.parse(match[0]) as Partial<AgentReply>;
        reply = {
          toolCalls: Array.isArray(parsed.toolCalls) ? parsed.toolCalls : [],
          finished: parsed.finished !== false,
          surfaceCapsuleID: parsed.surfaceCapsuleID ?? null,
        };
      }
    } catch {
      // 解析失败 —— 安全兜底为 hold，绝不误浮现。
      reply = { toolCalls: [], finished: true, surfaceCapsuleID: null };
    }

    return jsonResponse(reply);
  },
};
