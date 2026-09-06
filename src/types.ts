// ── Domain types (core contract, unchanged from V1) ──

export type StageName = "开场" | "探需" | "价值呈现" | "异议处理" | "收尾";

export type Capability =
  | "感知现实"
  | "诊断问题"
  | "建模人性"
  | "生成信任"
  | "拆解风险"
  | "设计决策"
  | "设计交换";

export type TranscriptLine = {
  start_ms: number;
  end_ms: number;
  speaker: "销售" | "客户";
  text: string;
  confidence: number;
};

export type StageSegment = {
  start_ms: number;
  end_ms: number;
  stage: StageName;
};

export type EvidenceRef = {
  start_ms: number;
  end_ms: number;
  quote: string;
};

export type Signal = {
  capability: Capability;
  verdict: "强" | "中" | "弱";
  behavior: string;
  evidence: EvidenceRef[];
  suggestion: string;
};

export type DecisiveMiss = {
  start_ms: number;
  end_ms: number;
  customer_quote: string;
  seller_reply: string;
  capability: Capability;
  why_it_matters: string;
  better_reply: string;
};

export type Persona = {
  role: string;
  budget_sensitivity: "高" | "中" | "低";
  decision_style: string;
  key_pains: string[];
  objections: string[];
  triggers: string[];
  evidence_refs: EvidenceRef[];
};

export type NextCallTalktrack = {
  opening: string;
  discovery_questions: string[];
  value_pitch: string;
  objection_handles: string[];
  close: string;
  do_not_say: string[];
};

// ── Public Interface 1: Transcript standard output ──

export type Utterance = {
  speaker: "销售" | "客户";
  start_ms: number;
  end_ms: number;
  text: string;
  confidence: number;
};

export type TranscriptResult = {
  utterances: Utterance[];
  raw?: unknown; // reserved for raw provider response
};

// ── Public Interface 2: Review standard output ──

export type ReviewResult = {
  transcript: TranscriptLine[];
  stages: StageSegment[];
  signals: Signal[];
  decisive_misses: DecisiveMiss[];
  persona: Persona;
  next_call_talktrack: NextCallTalktrack;
};

// ── Public Interface 3: Provider interfaces ──

export type TranscriptionProvider = {
  id: string;
  transcribe(audio: File, options?: { language?: string }): Promise<TranscriptResult>;
};

export type DiarizationProvider = {
  id: string;
  diarize(audio: File): Promise<TranscriptResult>;
};

export type ReviewAnalysisProvider = {
  id: string;
  analyze(transcript: TranscriptResult, input: ReviewInput): Promise<ReviewResult>;
};

// ── Review input ──

export type ReviewInput = {
  industry: string;
  callGoal: string;
  productName: string;
  productValue: string;
  fileName?: string;
  audioFile?: File;
};

// ── App config ──

export type AppConfig = {
  transcriptionProvider: string;
  analysisProvider: string;
  enableRealAI: boolean;
};

// ── Job state ──

export type JobState =
  | "idle"
  | "uploading"
  | "transcribing"
  | "analyzing"
  | "done"
  | "error";

// ── Local record (for localStorage persistence) ──

export type ReviewRecord = {
  id: string;
  createdAt: string;
  input: ReviewInput;
  transcript: TranscriptResult | null;
  review: ReviewResult | null;
  jobState: JobState;
  error?: string;
  providerMeta: {
    transcriptionProvider: string;
    analysisProvider: string;
  };
};

// ── Active view ──

export type ActiveView = "timeline" | "scorecard" | "talktrack";
