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
  // 设备鉴权 token，经 `wrangler secret put DEVICE_TOKEN` 注入，不入代码库。
  // 设备端必须带 `Authorization: Bearer <DEVICE_TOKEN>` 才能调用本代理。
  DEVICE_TOKEN: string;
  MODEL_ENDPOINT: string;
  MODEL_NAME: string;
}

// 请求正文上限 —— digest + 候选元数据 + 多轮历史远小于此；超出即拒（D2）。
const MAX_BODY_BYTES = 16 * 1024;

// ---- 与设备端约定的数据结构（对应 Swift 侧 DTO）----

interface ToolCall {
  name: string;
  arguments: Record<string, string>;
}

interface AgentReply {
  toolCalls: ToolCall[];
  finished: boolean;
  surfaceCapsuleID: string | null;
}

// 设备累积并整轮重发的对话历史（C3）。代理仍无状态 —— 历史由设备携带。
// content 用 string（设备整形后的文本），对应 Anthropic Messages API 的简单形态。
interface Message {
  role: 'user' | 'assistant';
  content: string;
}

interface RequestBody {
  sessionID?: string;
  // 设备每轮重发的完整对话历史。代理只把它原样转发给模型（注入 system）。
  messages?: Message[];
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

// 对客户端一律给不可探测的笼统错误（D23）——
// 真正的细节只 console.error 到服务端日志，绝不回给调用方。
function opaqueError(status: number): Response {
  return jsonResponse({ error: 'service unavailable' }, status);
}

/**
 * 常数时间字符串比较（D2）——
 * 避免按字符提前返回造成的计时旁路。两串长度不等时也走满全程，
 * 用长度差异置位 mismatch，使比较耗时与「哪一位不同」无关。
 */
function timingSafeEqual(a: string, b: string): boolean {
  const aBytes = new TextEncoder().encode(a);
  const bBytes = new TextEncoder().encode(b);
  const len = Math.max(aBytes.length, bBytes.length);
  let mismatch = aBytes.length === bBytes.length ? 0 : 1;
  for (let i = 0; i < len; i++) {
    mismatch |= (aBytes[i] ?? 0) ^ (bBytes[i] ?? 0);
  }
  return mismatch === 0;
}

// 设备鉴权（D2）：要求 `Authorization: Bearer <DEVICE_TOKEN>`。
function isAuthorized(request: Request, env: Env): boolean {
  if (!env.DEVICE_TOKEN) return false; // 未配 token 一律拒绝，绝不退化成开放代理。
  const header = request.headers.get('Authorization') ?? '';
  const prefix = 'Bearer ';
  if (!header.startsWith(prefix)) return false;
  const presented = header.slice(prefix.length);
  return timingSafeEqual(presented, env.DEVICE_TOKEN);
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // CORS：本代理仅供原生 App 调用，绝不反射任意 Origin、不发 CORS 头。
    // 浏览器跨域请求会因缺少 ACAO 而被拦在客户端 —— 这是有意的（D2）。
    if (request.method !== 'POST') {
      return jsonResponse({ error: 'method not allowed' }, 405);
    }

    // 配置缺失（缺 key 或缺 device token）—— 对外只给笼统错误，细节进日志（D23）。
    if (!env.MODEL_API_KEY || !env.DEVICE_TOKEN) {
      console.error(
        `proxy misconfigured: ${!env.MODEL_API_KEY ? 'missing MODEL_API_KEY ' : ''}` +
          `${!env.DEVICE_TOKEN ? 'missing DEVICE_TOKEN' : ''}`.trim()
      );
      return opaqueError(500);
    }

    // 设备鉴权（D2）：缺/错 token → 401，错误体不可探测。
    if (!isAuthorized(request, env)) {
      return jsonResponse({ error: 'unauthorized' }, 401);
    }

    // 请求正文上限（D2）：超出即 413，不读、不转发。
    const declared = Number(request.headers.get('Content-Length') ?? '');
    if (Number.isFinite(declared) && declared > MAX_BODY_BYTES) {
      return jsonResponse({ error: 'payload too large' }, 413);
    }

    // 即便没有/谎报 Content-Length，也按实际字节数兜底卡上限。
    const raw = await request.text();
    if (new TextEncoder().encode(raw).length > MAX_BODY_BYTES) {
      return jsonResponse({ error: 'payload too large' }, 413);
    }

    let body: RequestBody;
    try {
      body = JSON.parse(raw) as RequestBody;
    } catch {
      return jsonResponse({ error: 'invalid JSON' }, 400);
    }

    // C3：设备每轮重发完整对话历史。代理只校验形态、原样转发。
    const messages = body.messages;
    if (
      !Array.isArray(messages) ||
      messages.length === 0 ||
      !messages.every(
        (m) =>
          m &&
          (m.role === 'user' || m.role === 'assistant') &&
          typeof m.content === 'string'
      )
    ) {
      return jsonResponse({ error: 'invalid messages' }, 400);
    }

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
          messages,
        }),
      });
    } catch (err) {
      // 真正的传输错误只进服务端日志（D23）。
      console.error('upstream transport failed', err);
      return opaqueError(502);
    }

    if (!modelResponse.ok) {
      // 不回显上游状态码 —— 攻击者无法借此探测后端状态（D23）。
      console.error(`upstream status ${modelResponse.status}`);
      return opaqueError(502);
    }

    // 从模型回复里抽出那段 JSON，整形成 AgentReply。
    let reply: AgentReply = { toolCalls: [], finished: true, surfaceCapsuleID: null };
    try {
      const data = (await modelResponse.json()) as {
        content?: { type: string; text?: string }[];
      };
      const text = data.content?.find((c) => c.type === 'text')?.text ?? '';
      // 优先把整段当 JSON 解析；失败再回退到花括号截取（贪婪，仅作兜底）。
      const trimmed = text.trim();
      const jsonText =
        trimmed.startsWith('{') && trimmed.endsWith('}')
          ? trimmed
          : (text.match(/\{[\s\S]*\}/)?.[0] ?? null);
      if (jsonText) {
        const parsed = JSON.parse(jsonText) as Partial<AgentReply>;
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
