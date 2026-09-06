import type {
  TranscriptionProvider,
  DiarizationProvider,
  ReviewAnalysisProvider,
  TranscriptResult,
  TranscriptLine,
  ReviewResult,
  ReviewInput,
} from "../types";

// ── Mock transcription provider ──

export const mockTranscriptionProvider: TranscriptionProvider = {
  id: "mock",
  async transcribe(_audio: File, _options?: { language?: string }) {
    // Simulate processing delay
    await delay(300);
    return buildMockTranscript();
  },
};

function buildMockTranscript(): TranscriptResult {
  const utterances = [
    { speaker: "销售" as const, start_ms: 0, end_ms: 21000, text: "您好，我今天想跟您聊一下家庭保障方案，主要看看是否能帮您把保障做得更完整。", confidence: 0.94 },
    { speaker: "客户" as const, start_ms: 22000, end_ms: 43000, text: "我其实之前也了解过一些，但总觉得条款太复杂，而且预算也不想太高。", confidence: 0.91 },
    { speaker: "销售" as const, start_ms: 44000, end_ms: 68000, text: "这个产品性价比还是不错的，很多客户都会选这个版本，保障范围也比较全面。", confidence: 0.89 },
    { speaker: "客户" as const, start_ms: 69000, end_ms: 92000, text: "我主要担心理赔的时候麻烦，另外家里支出也挺多的。", confidence: 0.92 },
    { speaker: "销售" as const, start_ms: 93000, end_ms: 118000, text: "那我们可以先看一下价格，这个方案每年大概一万二，您觉得怎么样？", confidence: 0.90 },
    { speaker: "客户" as const, start_ms: 119000, end_ms: 146000, text: "我再考虑一下吧，现在马上定还是有点犹豫。", confidence: 0.93 },
    { speaker: "销售" as const, start_ms: 147000, end_ms: 173000, text: "可以的，那我回头把资料发您，您有问题再问我。", confidence: 0.95 },
  ];
  return { utterances, raw: { provider: "mock", generatedAt: new Date().toISOString() } };
}

// ── OpenAI transcription provider (placeholder, ready for real API) ──

export const openaiTranscriptionProvider: TranscriptionProvider = {
  id: "openai",
  async transcribe(audio: File, options?: { language?: string }) {
    // Placeholder: in production, call OpenAI Whisper API
    // const formData = new FormData();
    // formData.append("file", audio);
    // formData.append("model", "whisper-1");
    // if (options?.language) formData.append("language", options.language);
    // formData.append("response_format", "verbose_json");
    // const resp = await fetch("https://api.openai.com/v1/audio/transcriptions", {
    //   method: "POST",
    //   headers: { Authorization: `Bearer ${import.meta.env.VITE_OPENAI_API_KEY}` },
    //   body: formData,
    // });
    // ... map to TranscriptResult

    // For now, fallback to mock with a note
    await delay(500);
    const result = buildMockTranscript();
    result.raw = { provider: "openai", note: "placeholder – returns mock data until API key configured", generatedAt: new Date().toISOString() };
    return result;
  },
};

// ── No-op diarization provider ──

export const noopDiarizationProvider: DiarizationProvider = {
  id: "noop",
  async diarize(_audio: File) {
    // Return empty result – caller should fall back to transcription provider's output
    return { utterances: [], raw: { provider: "noop", note: "No diarization applied" } };
  },
};

// ── Template analysis provider ──

export const templateAnalysisProvider: ReviewAnalysisProvider = {
  id: "template",
  async analyze(transcript: TranscriptResult, input: ReviewInput) {
    await delay(200);
    return buildTemplateReview(transcript, input);
  },
};

// ── OpenAI analysis provider (placeholder, ready for real API) ──

export const openaiAnalysisProvider: ReviewAnalysisProvider = {
  id: "openai",
  async analyze(transcript: TranscriptResult, input: ReviewInput) {
    // Placeholder: in production, call OpenAI Chat API
    // const prompt = buildReviewPrompt(transcript, input);
    // const resp = await fetch("https://api.openai.com/v1/chat/completions", {
    //   method: "POST",
    //   headers: {
    //     Authorization: `Bearer ${import.meta.env.VITE_OPENAI_API_KEY}`,
    //     "Content-Type": "application/json",
    //   },
    //   body: JSON.stringify({
    //     model: "gpt-4o",
    //     messages: [{ role: "user", content: prompt }],
    //     response_format: { type: "json_object" },
    //   }),
    // });
    // ... map to ReviewResult

    // For now, fallback to template
    await delay(400);
    const result = buildTemplateReview(transcript, input);
    (result as Record<string, unknown>)._providerNote = "placeholder – returns template analysis until API key configured";
    return result;
  },
};

// ── Helper: template review builder (moved from old mockEngine) ──

function buildTemplateReview(transcript: TranscriptResult, input: ReviewInput): ReviewResult {
  const productName = input.productName || "家庭保障方案";
  const productValue =
    input.productValue || "用更低的年度预算覆盖家庭主要收入风险，并把理赔条件讲清楚";

  // Convert utterances to TranscriptLine[] for ReviewResult compatibility
  const transcriptLines: TranscriptLine[] = transcript.utterances.map((u) => ({
    start_ms: u.start_ms,
    end_ms: u.end_ms,
    speaker: u.speaker,
    text: u.text,
    confidence: u.confidence,
  }));

  return {
    transcript: transcriptLines,
    stages: [
      { start_ms: 0, end_ms: 21000, stage: "开场" },
      { start_ms: 22000, end_ms: 68000, stage: "探需" },
      { start_ms: 69000, end_ms: 118000, stage: "价值呈现" },
      { start_ms: 119000, end_ms: 146000, stage: "异议处理" },
      { start_ms: 147000, end_ms: 173000, stage: "收尾" },
    ],
    signals: [
      {
        capability: "感知现实",
        verdict: "中",
        behavior: "能捕捉到客户提到预算与条款复杂，但没有把两个顾虑拆开确认。",
        evidence: [{ start_ms: 22000, end_ms: 43000, quote: "条款太复杂，而且预算也不想太高。" }],
        suggestion: "先复述客户的两个顾虑，再问哪个是今天最影响决定的点。",
      },
      {
        capability: "诊断问题",
        verdict: "弱",
        behavior: "客户两次表达真实顾虑后，销售都直接进入产品或价格，没有追问原因。",
        evidence: [{ start_ms: 69000, end_ms: 92000, quote: "我主要担心理赔的时候麻烦，另外家里支出也挺多的。" }],
        suggestion: '用"您担心理赔麻烦，主要是之前听过案例，还是不确定哪些情况能赔？"继续挖。',
      },
      {
        capability: "拆解风险",
        verdict: "弱",
        behavior: '客户提出"理赔麻烦"后，没有拆成材料、流程、责任范围或服务支持。',
        evidence: [{ start_ms: 93000, end_ms: 118000, quote: "那我们可以先看一下价格。" }],
        suggestion: "先把风险拆小，再给证据：哪些情况能赔、谁协助、通常多久处理。",
      },
      {
        capability: "设计交换",
        verdict: "中",
        behavior: "报价出现得较早，价值锚定不足，客户容易只比较价格。",
        evidence: [{ start_ms: 93000, end_ms: 118000, quote: "每年大概一万二，您觉得怎么样？" }],
        suggestion: `报价前先锚定交换：${productValue}。`,
      },
      {
        capability: "建模人性",
        verdict: "中",
        behavior: "客户偏风险规避型，真正担心的是未来出事时不确定，而不是单纯嫌贵。",
        evidence: [{ start_ms: 119000, end_ms: 146000, quote: "马上定还是有点犹豫。" }],
        suggestion: '不要继续压成交，改用"把不确定点列出来逐个排除"的推进方式。',
      },
    ],
    decisive_misses: [
      {
        start_ms: 69000,
        end_ms: 118000,
        customer_quote: "我主要担心理赔的时候麻烦，另外家里支出也挺多的。",
        seller_reply: "那我们可以先看一下价格，这个方案每年大概一万二。",
        capability: "拆解风险",
        why_it_matters:
          '客户抛出的核心异议是"理赔不确定性"，销售却切到报价，导致客户把注意力转向成本，而不是风险被解决。',
        better_reply:
          "我先不急着报价。您说理赔麻烦，我想确认一下，您更担心的是条款看不懂、材料准备麻烦，还是怕真正出险时没人协助？",
      },
      {
        start_ms: 119000,
        end_ms: 173000,
        customer_quote: "我再考虑一下吧，现在马上定还是有点犹豫。",
        seller_reply: "那我回头把资料发您，您有问题再问我。",
        capability: "设计决策",
        why_it_matters:
          '"再考虑一下"没有被拆解，销售把下一步交还给客户，等于让客户独自面对复杂决策。',
        better_reply:
          "可以，您不用现在定。我们先把要考虑的点列清楚：预算、理赔、保障范围。这里面哪一个如果弄明白，您最容易往前走？",
      },
    ],
    persona: {
      role: input.industry === "房产" ? "改善型购房客户" : "家庭责任承担者",
      budget_sensitivity: "高",
      decision_style: "风险规避型，先排除不确定性，再接受方案比较",
      key_pains: ["怕条款复杂", "担心理赔不顺", "家庭现金流压力"],
      objections: ["预算不想太高", "需要再考虑", "不确定理赔是否麻烦"],
      triggers: ["清晰流程", "可比较方案", "有人协助处理后续问题"],
      evidence_refs: [
        { start_ms: 22000, end_ms: 43000, quote: "条款太复杂，而且预算也不想太高。" },
        { start_ms: 69000, end_ms: 92000, quote: "我主要担心理赔的时候麻烦。" },
      ],
    },
    next_call_talktrack: {
      opening: "上次您提到两个点：预算不能太高，以及理赔时怕麻烦。今天我想先把这两个问题拆清楚，不急着让您决定。",
      discovery_questions: [
        "如果只看理赔，您最担心的是材料、流程，还是条款边界？",
        "家庭预算里，您觉得每年多少以内是可以安心讨论的范围？",
        "如果有两个方案，一个便宜但责任少，一个贵一点但关键风险覆盖更完整，您会怎么比较？",
      ],
      value_pitch: `${productName}的价值不是"多买一份东西"，而是用可控预算换一个关键风险发生时有人负责、流程清楚的解决方案。`,
      objection_handles: [
        "您说再考虑一下很正常，我们先把要考虑的点列出来，不让它变成一团模糊压力。",
        "如果预算是主要点，我给您做两个版本：基础防大风险，增强版补关键缺口。",
      ],
      close: "这次我们不做复杂决定，只确认一个下一步：您更愿意先看预算版本，还是先看理赔流程说明？",
      do_not_say: ["这个产品很多人都买", "性价比很高", "您觉得这个价格怎么样"],
    },
  };
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
