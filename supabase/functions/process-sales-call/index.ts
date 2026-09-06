import "@supabase/functions-js/edge-runtime.d.ts"

const MAX_BYTES = 25 * 1024 * 1024
const json = (status: number, body: Record<string, unknown>) => new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } })
class HttpError extends Error { constructor(readonly status: number, message: string) { super(message) } }
const env = (name: string) => { const value = Deno.env.get(name)?.trim(); if (!value) throw new HttpError(500, `Missing function secret: ${name}`); return value }
const url = () => env("SUPABASE_URL").replace(/\/$/, "")
const uuid = (value: unknown): value is string => typeof value === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)
const record = (value: unknown): value is Record<string, unknown> => !!value && typeof value === "object" && !Array.isArray(value)
const errText = async (res: Response) => (await res.text()).replace(/\s+/g, " ").slice(0, 400) || `HTTP ${res.status}`
function serviceKey(): string {
  // A JSON dictionary supports key rotation without changing function code.
  // Supabase names the default generated secret key "default".
  try {
    const keys = JSON.parse(env("SUPABASE_SECRET_KEYS")) as Record<string, unknown>
    const key = keys.default ?? keys.service_role
    if (typeof key === "string" && key.trim()) return key.trim()
  } catch { /* report the safe configuration error below */ }
  throw new HttpError(500, "SUPABASE_SECRET_KEYS must be JSON with a default secret key")
}
const serviceHeaders = (): HeadersInit => { const key = serviceKey(); return { apikey: key, authorization: `Bearer ${key}`, "content-type": "application/json" } }
const rest = (path: string, init: RequestInit = {}) => fetch(`${url()}/rest/v1/${path}`, { ...init, headers: { ...serviceHeaders(), ...init.headers } })

async function caller(req: Request): Promise<string> {
  const authorization = req.headers.get("authorization")
  if (!authorization?.startsWith("Bearer ")) throw new HttpError(401, "Missing bearer token")
  const res = await fetch(`${url()}/auth/v1/user`, { headers: { apikey: env("SUPABASE_ANON_KEY"), authorization } })
  if (!res.ok) throw new HttpError(401, "Invalid or expired bearer token")
  const user = await res.json() as { id?: unknown }
  if (typeof user.id !== "string") throw new HttpError(401, "Invalid authenticated user")
  return user.id
}

type Call = { id: string; user_id: string; audio_path: string | null; title: string; industry: string; call_goal: string }
async function ownedCall(callId: string, userId: string): Promise<Call> {
  const q = new URLSearchParams({ select: "id,user_id,audio_path,title,industry,call_goal", id: `eq.${callId}`, user_id: `eq.${userId}` })
  const res = await rest(`calls?${q}`); if (!res.ok) throw new HttpError(500, `Unable to load call: ${await errText(res)}`)
  const calls = await res.json() as Call[]; if (calls.length !== 1) throw new HttpError(404, "Call was not found")
  return calls[0]
}
async function patchCall(callId: string, userId: string, body: Record<string, unknown>) {
  const q = new URLSearchParams({ id: `eq.${callId}`, user_id: `eq.${userId}` }); const res = await rest(`calls?${q}`, { method: "PATCH", body: JSON.stringify(body) })
  if (!res.ok) throw new HttpError(500, `Unable to update call: ${await errText(res)}`)
}
async function job(callId: string, userId: string, job_type: string, provider: string, model: string): Promise<string> {
  const res = await rest("analysis_jobs", { method: "POST", headers: { Prefer: "return=representation" }, body: JSON.stringify({ call_id: callId, user_id: userId, job_type, status: "running", progress: 1, provider, model, started_at: new Date().toISOString(), attempt_count: 1 }) })
  if (!res.ok) throw new HttpError(500, `Unable to create processing job: ${await errText(res)}`)
  const rows = await res.json() as Array<{ id?: string }>; if (!rows[0]?.id) throw new HttpError(500, "Unable to create processing job"); return rows[0].id
}
async function patchJob(id: string, body: Record<string, unknown>) { const res = await rest(`analysis_jobs?id=eq.${id}`, { method: "PATCH", body: JSON.stringify(body) }); if (!res.ok) throw new HttpError(500, `Unable to update processing job: ${await errText(res)}`) }

function validPath(path: string, userId: string, callId: string) { const parts = path.split("/"); return parts.length === 3 && parts[0] === userId && parts[1] === callId && parts.every((part) => part && part !== "." && part !== "..") }
async function audio(path: string): Promise<{ blob: Blob; type: string }> {
  const objectUrl = `${url()}/storage/v1/object/call-audio/${path.split("/").map(encodeURIComponent).join("/")}`
  const headers = serviceHeaders(); const head = await fetch(objectUrl, { method: "HEAD", headers }); if (!head.ok) throw new HttpError(404, "Audio object was not found")
  const size = Number(head.headers.get("content-length")); if (Number.isFinite(size) && size > MAX_BYTES) throw new HttpError(413, "Audio must be 25 MiB or smaller")
  const type = head.headers.get("content-type")?.split(";")[0] ?? "application/octet-stream"
  if (!type.startsWith("audio/") && type !== "video/mp4" && type !== "video/quicktime") throw new HttpError(415, "Unsupported audio content type")
  const get = await fetch(objectUrl, { headers }); if (!get.ok) throw new HttpError(404, "Audio object was not found")
  const blob = await get.blob(); if (!blob.size || blob.size > MAX_BYTES) throw new HttpError(413, "Audio must be between 1 byte and 25 MiB")
  return { blob, type }
}
async function transcribe(blob: Blob, type: string, path: string) {
  const base = (Deno.env.get("OPENAI_TRANSCRIPTION_BASE_URL") ?? "https://api.openai.com/v1").replace(/\/$/, "")
  const model = Deno.env.get("OPENAI_TRANSCRIPTION_MODEL") ?? "whisper-1"; const form = new FormData(); form.set("model", model); form.set("response_format", "verbose_json")
  form.set("file", new File([blob], path.split("/").at(-1) ?? "recording.m4a", { type }))
  const res = await fetch(`${base}/audio/transcriptions`, { method: "POST", headers: { authorization: `Bearer ${env("OPENAI_TRANSCRIPTION_API_KEY")}` }, body: form })
  if (!res.ok) throw new HttpError(502, `Transcription provider failed: ${await errText(res)}`)
  const data = await res.json() as { text?: unknown; segments?: unknown }; if (typeof data.text !== "string" || !data.text.trim()) throw new HttpError(502, "Transcription provider returned no text")
  return { text: data.text.trim(), segments: Array.isArray(data.segments) ? data.segments.filter(record) : [] }
}
const string = (value: unknown, fallback = "") => typeof value === "string" && value.trim() ? value.trim() : fallback
const integer = (value: unknown, fallback = 0) => Number.isFinite(Number(value)) ? Math.max(0, Math.round(Number(value))) : fallback
const array = (value: unknown): unknown[] => Array.isArray(value) ? value : []
const field = (source: Record<string, unknown>, camel: string, snake: string) => source[camel] ?? source[snake]

type TranscriptLine = { startMS: number; endMS: number; speaker: string; text: string; confidence: number }
function transcriptLines(text: string, segments: Record<string, unknown>[]): TranscriptLine[] {
  const source = segments.length ? segments : [{ start: 0, end: 0, text }]
  return source.map((s) => ({ startMS: integer(Number(s.start ?? 0) * 1000), endMS: integer(Number(s.end ?? s.start ?? 0) * 1000), speaker: string(s.speaker, "unknown"), text: string(s.text, text), confidence: typeof s.confidence === "number" ? s.confidence : typeof s.avg_logprob === "number" ? s.avg_logprob : 0 }))
}
async function saveTranscript(callId: string, lines: TranscriptLine[]) {
  const rows = lines.map((line) => ({ call_id: callId, start_ms: line.startMS, end_ms: line.endMS, speaker: line.speaker, text: line.text, confidence: line.confidence }))
  const res = await rest("transcript_segments", { method: "POST", body: JSON.stringify(rows) }); if (!res.ok) throw new HttpError(500, `Unable to save transcript: ${await errText(res)}`)
}
async function analyze(call: Call, transcript: string): Promise<Record<string, unknown>> {
  const prompt = `You are a rigorous sales-call coach. Analyze the following call in Chinese. Return ONLY JSON matching this exact ReviewResult shape: {"stages":[{"startMS":0,"endMS":0,"stage":""}],"signals":[{"capability":"","verdict":"","behavior":"","evidence":[{"startMS":0,"endMS":0,"quote":""}],"suggestion":""}],"decisiveMisses":[{"startMS":0,"endMS":0,"customerQuote":"","sellerReply":"","capability":"","whyItMatters":"","betterReply":""}],"persona":{"role":"","budgetSensitivity":"","decisionStyle":"","keyPains":[],"objections":[],"triggers":[],"evidenceRefs":[]},"nextCallTalktrack":{"opening":"","discoveryQuestions":[],"valuePitch":"","objectionHandles":[],"close":"","doNotSay":[]}}. Do not include transcript; it is supplied by transcription. Do not invent quotes or timestamps.\nTitle: ${call.title}\nIndustry: ${call.industry}\nGoal: ${call.call_goal}\n\nTranscript:\n${transcript}`
  const res = await fetch(`${env("ANALYSIS_BASE_URL").replace(/\/$/, "")}/chat/completions`, { method: "POST", headers: { authorization: `Bearer ${env("ANALYSIS_API_KEY")}`, "content-type": "application/json" }, body: JSON.stringify({ model: env("ANALYSIS_MODEL"), temperature: 0.2, response_format: { type: "json_object" }, messages: [{ role: "system", content: "Return valid JSON only; never use markdown fences." }, { role: "user", content: prompt }] }) })
  if (!res.ok) throw new HttpError(502, `Analysis provider failed: ${await errText(res)}`)
  const data = await res.json() as { choices?: Array<{ message?: { content?: unknown } }> }; const content = data.choices?.[0]?.message?.content
  try { const parsed = typeof content === "string" ? JSON.parse(content) : null; if (!record(parsed)) throw new Error(); return parsed } catch { throw new HttpError(502, "Analysis provider returned invalid JSON") }
}
function evidence(value: unknown) { const v = record(value) ? value : {}; return { startMS: integer(field(v, "startMS", "start_ms")), endMS: integer(field(v, "endMS", "end_ms")), quote: string(v.quote) } }
function normalizeReview(analysis: Record<string, unknown>, transcript: TranscriptLine[]) {
  const personaSource = record(analysis.persona) ? analysis.persona : {}
  const talktrackSource = record(field(analysis, "nextCallTalktrack", "next_call_talktrack")) ? field(analysis, "nextCallTalktrack", "next_call_talktrack") as Record<string, unknown> : {}
  return {
    transcript,
    stages: array(analysis.stages).map((item) => { const v = record(item) ? item : {}; return { startMS: integer(field(v, "startMS", "start_ms")), endMS: integer(field(v, "endMS", "end_ms")), stage: string(v.stage) } }),
    signals: array(analysis.signals).map((item) => { const v = record(item) ? item : {}; return { capability: string(v.capability), verdict: string(v.verdict), behavior: string(v.behavior), evidence: array(v.evidence).map(evidence), suggestion: string(v.suggestion) } }),
    decisiveMisses: array(field(analysis, "decisiveMisses", "decisive_misses")).map((item) => { const v = record(item) ? item : {}; return { startMS: integer(field(v, "startMS", "start_ms")), endMS: integer(field(v, "endMS", "end_ms")), customerQuote: string(field(v, "customerQuote", "customer_quote")), sellerReply: string(field(v, "sellerReply", "seller_reply")), capability: string(v.capability), whyItMatters: string(field(v, "whyItMatters", "why_it_matters")), betterReply: string(field(v, "betterReply", "better_reply")) } }),
    persona: { role: string(personaSource.role), budgetSensitivity: string(field(personaSource, "budgetSensitivity", "budget_sensitivity")), decisionStyle: string(field(personaSource, "decisionStyle", "decision_style")), keyPains: array(field(personaSource, "keyPains", "key_pains")).map((x) => string(x)), objections: array(personaSource.objections).map((x) => string(x)), triggers: array(personaSource.triggers).map((x) => string(x)), evidenceRefs: array(field(personaSource, "evidenceRefs", "evidence_refs")).map(evidence) },
    nextCallTalktrack: { opening: string(talktrackSource.opening), discoveryQuestions: array(field(talktrackSource, "discoveryQuestions", "discovery_questions")).map((x) => string(x)), valuePitch: string(field(talktrackSource, "valuePitch", "value_pitch")), objectionHandles: array(field(talktrackSource, "objectionHandles", "objection_handles")).map((x) => string(x)), close: string(talktrackSource.close), doNotSay: array(field(talktrackSource, "doNotSay", "do_not_say")).map((x) => string(x)) },
  }
}
async function saveReview(callId: string, review: ReturnType<typeof normalizeReview>) {
  const body = { call_id: callId, persona: review.persona, decisive_misses: review.decisiveMisses, signals: review.signals, next_call_talktrack: review.nextCallTalktrack, full_result: review }
  const res = await rest("review_results", { method: "POST", body: JSON.stringify(body) }); if (!res.ok) throw new HttpError(500, `Unable to save analysis: ${await errText(res)}`)
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "Method not allowed" })
  let callId: string | undefined, userId: string | undefined, activeJob: string | undefined
  try {
    const body = await req.json() as { callId?: unknown; audioPath?: unknown }; if (!uuid(body.callId)) throw new HttpError(400, "callId must be a UUID"); callId = body.callId; userId = await caller(req)
    const call = await ownedCall(callId, userId); const path = typeof body.audioPath === "string" ? body.audioPath : call.audio_path
    if (!path || !validPath(path, userId, callId)) throw new HttpError(403, "Audio path is not owned by this call")
    activeJob = await job(callId, userId, "transcription", "openai", Deno.env.get("OPENAI_TRANSCRIPTION_MODEL") ?? "whisper-1"); await patchCall(callId, userId, { audio_path: path, status: "transcribing", error_message: null })
    const file = await audio(path); const transcript = await transcribe(file.blob, file.type, path); const lines = transcriptLines(transcript.text, transcript.segments); await saveTranscript(callId, lines); await patchJob(activeJob, { status: "completed", progress: 100, completed_at: new Date().toISOString() })
    activeJob = await job(callId, userId, "review_analysis", "openai-compatible", env("ANALYSIS_MODEL")); await patchCall(callId, userId, { status: "analyzing" }); const analysis = await analyze(call, transcript.text); await saveReview(callId, normalizeReview(analysis, lines)); await patchJob(activeJob, { status: "completed", progress: 100, completed_at: new Date().toISOString() }); await patchCall(callId, userId, { status: "completed", error_message: null })
    return json(200, { callId, status: "completed" })
  } catch (error) {
    const message = (error instanceof Error ? error.message : "Unexpected processing error").slice(0, 500); if (activeJob) await patchJob(activeJob, { status: "failed", error_message: message, completed_at: new Date().toISOString() }).catch(() => undefined); if (callId && userId) await patchCall(callId, userId, { status: "failed", error_message: message }).catch(() => undefined)
    return json(error instanceof HttpError ? error.status : 500, { error: message })
  }
})
