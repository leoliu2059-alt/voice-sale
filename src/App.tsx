import {
  AlertTriangle,
  BarChart3,
  CheckCircle2,
  ClipboardList,
  Clock,
  FileAudio,
  Mic,
  Play,
  RefreshCw,
  ShieldCheck,
  Sparkles,
  Trash2,
  Upload,
  XCircle,
} from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import type {
  ActiveView,
  JobState,
  ReviewInput,
  ReviewRecord,
  ReviewResult,
  StageName,
  TranscriptResult,
} from "./types";
import { runReviewPipeline } from "./orchestrator";
import {
  loadRecords,
  addRecord,
  updateRecord,
  deleteRecord,
  saveLastInput,
  loadLastInput,
} from "./store";
import { getEffectiveConfig } from "./config";

// ── Constants ──

const stages: StageName[] = ["开场", "探需", "价值呈现", "异议处理", "收尾"];

const defaultInput: ReviewInput = {
  industry: "保险",
  callGoal: "促成下一次方案沟通",
  productName: "家庭收入保障方案",
  productValue: "用可控预算覆盖家庭主要收入风险，并用清晰理赔流程降低不确定性",
};

// ── Helpers ──

function formatTime(ms: number) {
  const totalSeconds = Math.floor(ms / 1000);
  const minutes = Math.floor(totalSeconds / 60)
    .toString()
    .padStart(2, "0");
  const seconds = (totalSeconds % 60).toString().padStart(2, "0");
  return `${minutes}:${seconds}`;
}

function jobLabel(state: JobState): string {
  switch (state) {
    case "uploading": return "切片上传";
    case "transcribing": return "语音转写";
    case "analyzing": return "结构诊断";
    case "done": return "复盘完成";
    case "error": return "处理失败";
    default: return "等待开始";
  }
}

function formatDate(iso: string): string {
  try {
    const d = new Date(iso);
    return d.toLocaleString("zh-CN", {
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
    });
  } catch {
    return iso;
  }
}

// ── App ──

export function App() {
  const config = getEffectiveConfig();

  const [input, setInput] = useState<ReviewInput>(() => loadLastInput() ?? defaultInput);
  const [jobState, setJobState] = useState<JobState>("idle");
  const [activeView, setActiveView] = useState<ActiveView>("scorecard");
  const [sellerSpeaker, setSellerSpeaker] = useState<"A" | "B">("A");
  const [review, setReview] = useState<ReviewResult | null>(null);
  const [transcript, setTranscript] = useState<TranscriptResult | null>(null);
  const [currentRecordId, setCurrentRecordId] = useState<string | null>(null);
  const [errorMsg, setErrorMsg] = useState<string>("");
  const [records, setRecords] = useState<ReviewRecord[]>(() => loadRecords());
  const [showHistory, setShowHistory] = useState(false);

  // Persist last input when it changes
  useEffect(() => {
    saveLastInput(input);
  }, [input]);

  const progress = useMemo(() => {
    if (jobState === "idle") return 0;
    if (jobState === "uploading") return 28;
    if (jobState === "transcribing") return 62;
    if (jobState === "analyzing") return 84;
    if (jobState === "done") return 100;
    if (jobState === "error") return 0;
    return 0;
  }, [jobState]);

  const runAnalysis = async () => {
    setJobState("uploading");
    setErrorMsg("");

    const providerMeta = {
      transcriptionProvider: config.transcriptionProvider,
      analysisProvider: config.analysisProvider,
    };

    // Create a local record
    const record = addRecord(input, providerMeta);
    setCurrentRecordId(record.id);
    updateRecord(record.id, { jobState: "uploading" });

    try {
      const result = await runReviewPipeline(input, {
        onProgress: (stage, _percent) => {
          const stateMap: Record<string, JobState> = {
            uploading: "uploading",
            transcribing: "transcribing",
            analyzing: "analyzing",
          };
          const state = stateMap[stage] ?? "analyzing";
          setJobState(state);
          updateRecord(record.id, { jobState: state });
        },
      });

      setTranscript(result.transcript);
      setReview(result.review);
      setJobState("done");
      setActiveView("scorecard");
      updateRecord(record.id, {
        transcript: result.transcript,
        review: result.review,
        jobState: "done",
      });
      setRecords(loadRecords());
    } catch (err) {
      const msg = err instanceof Error ? err.message : "处理失败，请重试";
      setErrorMsg(msg);
      setJobState("error");
      updateRecord(record.id, { jobState: "error", error: msg });
      setRecords(loadRecords());
    }
  };

  const handleDeleteRecord = (id: string) => {
    deleteRecord(id);
    setRecords(loadRecords());
    if (currentRecordId === id) {
      setCurrentRecordId(null);
      setReview(null);
      setTranscript(null);
      setJobState("idle");
    }
  };

  const handleViewRecord = (record: ReviewRecord) => {
    setCurrentRecordId(record.id);
    setInput(record.input);
    setReview(record.review);
    setTranscript(record.transcript);
    setJobState(record.jobState);
    setShowHistory(false);
    if (record.review) {
      setActiveView("scorecard");
    }
  };

  const handleRetry = () => {
    setJobState("idle");
    setErrorMsg("");
    runAnalysis();
  };

  const updateInput = (key: keyof ReviewInput, value: string) => {
    setInput((current) => ({ ...current, [key]: value }));
  };

  const handleAudioFile = (file: File | undefined) => {
    if (file) {
      setInput((current) => ({ ...current, fileName: file.name, audioFile: file }));
    }
  };

  const canRun = jobState !== "uploading" && jobState !== "transcribing" && jobState !== "analyzing";

  return (
    <main className="app-shell">
      {/* ── Topbar ── */}
      <header className="topbar">
        <div>
          <p className="eyebrow">VoiceSale Review</p>
          <h1>语销镜</h1>
        </div>
        <div className="top-actions">
          <button
            className={showHistory ? "mode active" : "mode"}
            onClick={() => setShowHistory((v) => !v)}
          >
            <Clock size={16} />
            历史记录 ({records.length})
          </button>
        </div>
      </header>

      {/* ── Workspace ── */}
      <section className="workspace">
        {/* ── Left Panel: Input ── */}
        <aside className="panel intake-panel">
          <div className="panel-title">
            <FileAudio size={18} />
            <span>复盘输入</span>
          </div>

          <label className="dropzone" htmlFor="audio-upload">
            <Upload size={28} />
            <strong>{input.fileName || "上传销售对话音频（可选）"}</strong>
            <span>支持 mp3 / wav / m4a；不上传也可跑通模板演示</span>
            <input
              id="audio-upload"
              type="file"
              accept="audio/*,video/*"
              onChange={(event) => handleAudioFile(event.target.files?.[0])}
            />
          </label>

          <div className="record-row">
            <button className="secondary-button" disabled>
              <Mic size={16} />
              本地录音
            </button>
            <button
              className="secondary-button"
              onClick={() => {
                setInput({ ...defaultInput, fileName: undefined, audioFile: undefined });
              }}
            >
              <RefreshCw size={16} />
              重置输入
            </button>
          </div>

          <div className="field-grid">
            <label>
              行业
              <select value={input.industry} onChange={(event) => updateInput("industry", event.target.value)}>
                <option>保险</option>
                <option>房产</option>
                <option>教育</option>
                <option>SaaS</option>
              </select>
            </label>
            <label>
              通话目标
              <input value={input.callGoal} onChange={(event) => updateInput("callGoal", event.target.value)} />
            </label>
            <label>
              我的产品
              <input value={input.productName} onChange={(event) => updateInput("productName", event.target.value)} />
            </label>
            <label>
              核心价值
              <textarea value={input.productValue} onChange={(event) => updateInput("productValue", event.target.value)} />
            </label>
          </div>

          <div className="speaker-switch">
            <span>销售说话人</span>
            <div>
              <button className={sellerSpeaker === "A" ? "chip active" : "chip"} onClick={() => setSellerSpeaker("A")}>A</button>
              <button className={sellerSpeaker === "B" ? "chip active" : "chip"} onClick={() => setSellerSpeaker("B")}>B</button>
            </div>
          </div>

          <button className="primary-button" onClick={runAnalysis} disabled={!canRun}>
            <Sparkles size={18} />
            {jobState === "done" ? "重新复盘" : "生成复盘评分卡"}
          </button>

          <div className="job-box">
            <div>
              <span>{jobLabel(jobState)}</span>
              <strong>{progress}%</strong>
            </div>
            <div className="progress">
              <span style={{ width: `${progress}%` }} />
            </div>
            <p>
              Provider: {config.transcriptionProvider} / {config.analysisProvider}
              {config.enableRealAI ? " (真实AI)" : " (模板)"}
            </p>
          </div>

          {jobState === "error" && (
            <div className="error-box">
              <XCircle size={16} />
              <span>{errorMsg}</span>
              <button className="secondary-button" onClick={handleRetry}>
                <RefreshCw size={14} />
                重试
              </button>
            </div>
          )}
        </aside>

        {/* ── Center: Main View ── */}
        <section className="main-panel">
          <nav className="tabs" aria-label="复盘视图">
            <button className={activeView === "timeline" ? "tab active" : "tab"} onClick={() => setActiveView("timeline")}>
              <ClipboardList size={16} />
              时间轴
            </button>
            <button className={activeView === "scorecard" ? "tab active" : "tab"} onClick={() => setActiveView("scorecard")}>
              <BarChart3 size={16} />
              评分卡
            </button>
            <button className={activeView === "talktrack" ? "tab active" : "tab"} onClick={() => setActiveView("talktrack")}>
              <Play size={16} />
              下一通
            </button>
          </nav>

          {jobState === "error" ? (
            <ErrorState message={errorMsg} onRetry={handleRetry} />
          ) : !review ? (
            <EmptyState onRun={runAnalysis} />
          ) : activeView === "timeline" ? (
            <Timeline review={review} />
          ) : activeView === "scorecard" ? (
            <Scorecard review={review} />
          ) : (
            <Talktrack review={review} />
          )}
        </section>

        {/* ── Right Panel: Persona + History ── */}
        <aside className="panel insight-panel">
          {showHistory ? (
            <>
              <div className="panel-title">
                <Clock size={18} />
                <span>历史记录</span>
              </div>
              <HistoryList
                records={records}
                activeId={currentRecordId}
                onView={handleViewRecord}
                onDelete={handleDeleteRecord}
              />
            </>
          ) : (
            <>
              <div className="panel-title">
                <ShieldCheck size={18} />
                <span>用户画像</span>
              </div>
              {review ? (
                <PersonaCard review={review} />
              ) : (
                <div className="placeholder-copy">
                  <p>生成复盘后，这里会汇总客户角色、预算敏感度、决策风格、核心顾虑和触发点。</p>
                </div>
              )}

              <div className="contract-box">
                <div className="panel-title compact">
                  <CheckCircle2 size={17} />
                  <span>标准契约</span>
                </div>
                <code>
                  transcript · stages · signals · decisive_misses · persona · next_call_talktrack
                </code>
              </div>
            </>
          )}
        </aside>
      </section>
    </main>
  );
}

// ── Empty State ──

function EmptyState({ onRun }: { onRun: () => void }) {
  return (
    <div className="empty-state">
      <AlertTriangle size={34} />
      <h2>先跑通一条销售复盘</h2>
      <p>当前版本用样例引擎模拟"长音频转写、阶段切分、能力诊断、决定性失分点、下一通话术"的完整链路。</p>
      <p>上传真实音频文件可走转写→分析完整流程。</p>
      <button className="primary-button" onClick={onRun}>
        <Sparkles size={18} />
        查看样例结果
      </button>
    </div>
  );
}

// ── Error State ──

function ErrorState({ message, onRetry }: { message: string; onRetry: () => void }) {
  return (
    <div className="empty-state">
      <XCircle size={34} color="#8f2c17" />
      <h2>处理失败</h2>
      <p>{message}</p>
      <button className="primary-button" onClick={onRetry}>
        <RefreshCw size={18} />
        重试
      </button>
    </div>
  );
}

// ── Timeline View ──

function Timeline({ review }: { review: ReviewResult }) {
  return (
    <div className="view-scroll">
      <div className="stage-strip">
        {stages.map((stage) => (
          <span key={stage}>{stage}</span>
        ))}
      </div>
      <div className="timeline">
        {review.transcript.map((line) => (
          <article key={`${line.start_ms}-${line.end_ms}`} className={`utterance ${line.speaker === "销售" ? "seller" : "customer"}`}>
            <button className="time-button">{formatTime(line.start_ms)}</button>
            <div>
              <strong>{line.speaker}</strong>
              <p>{line.text}</p>
              <span>置信度 {Math.round(line.confidence * 100)}%</span>
            </div>
          </article>
        ))}
      </div>
    </div>
  );
}

// ── Scorecard View ──

function Scorecard({ review }: { review: ReviewResult }) {
  return (
    <div className="view-scroll">
      <section className="miss-grid">
        {review.decisive_misses.map((miss) => (
          <article className="miss-card" key={miss.start_ms}>
            <div className="miss-head">
              <span>{formatTime(miss.start_ms)}</span>
              <strong>{miss.capability}</strong>
            </div>
            <blockquote>客户："{miss.customer_quote}"</blockquote>
            <p className="reply">销售："{miss.seller_reply}"</p>
            <p>{miss.why_it_matters}</p>
            <div className="better-reply">{miss.better_reply}</div>
          </article>
        ))}
      </section>

      <section className="signal-list">
        {review.signals.map((signal) => (
          <article className="signal-row" key={signal.capability}>
            <div className={`verdict ${signal.verdict}`}>{signal.verdict}</div>
            <div>
              <h3>{signal.capability}</h3>
              <p>{signal.behavior}</p>
              <span>{signal.evidence[0]?.quote}</span>
            </div>
            <strong>{signal.suggestion}</strong>
          </article>
        ))}
      </section>
    </div>
  );
}

// ── Talktrack View ──

function Talktrack({ review }: { review: ReviewResult }) {
  return (
    <div className="view-scroll talktrack">
      <section>
        <h2>下一通开场</h2>
        <p>{review.next_call_talktrack.opening}</p>
      </section>
      <section>
        <h2>探需问题</h2>
        {review.next_call_talktrack.discovery_questions.map((question) => (
          <div className="script-line" key={question}>{question}</div>
        ))}
      </section>
      <section>
        <h2>价值表达</h2>
        <p>{review.next_call_talktrack.value_pitch}</p>
      </section>
      <section>
        <h2>异议处理</h2>
        {review.next_call_talktrack.objection_handles.map((handle) => (
          <div className="script-line" key={handle}>{handle}</div>
        ))}
      </section>
      <section className="avoid-box">
        <h2>不要这样说</h2>
        {review.next_call_talktrack.do_not_say.map((line) => (
          <span key={line}>{line}</span>
        ))}
      </section>
    </div>
  );
}

// ── Persona Card ──

function PersonaCard({ review }: { review: ReviewResult }) {
  const persona = review.persona;
  return (
    <div className="persona-card">
      <dl>
        <div>
          <dt>角色</dt>
          <dd>{persona.role}</dd>
        </div>
        <div>
          <dt>预算敏感度</dt>
          <dd>{persona.budget_sensitivity}</dd>
        </div>
        <div>
          <dt>决策风格</dt>
          <dd>{persona.decision_style}</dd>
        </div>
      </dl>
      <h3>核心顾虑</h3>
      <div className="tag-list">
        {persona.key_pains.map((pain) => (
          <span key={pain}>{pain}</span>
        ))}
      </div>
      <h3>触发点</h3>
      <div className="tag-list">
        {persona.triggers.map((trigger) => (
          <span key={trigger}>{trigger}</span>
        ))}
      </div>
      <h3>证据</h3>
      {persona.evidence_refs.map((evidence) => (
        <p className="evidence" key={evidence.start_ms}>
          {formatTime(evidence.start_ms)} · {evidence.quote}
        </p>
      ))}
    </div>
  );
}

// ── History List ──

function HistoryList({
  records,
  activeId,
  onView,
  onDelete,
}: {
  records: ReviewRecord[];
  activeId: string | null;
  onView: (r: ReviewRecord) => void;
  onDelete: (id: string) => void;
}) {
  if (records.length === 0) {
    return (
      <div className="placeholder-copy">
        <p>暂无复盘记录。填写左侧信息后点击"生成复盘评分卡"开始。</p>
      </div>
    );
  }

  return (
    <div className="history-list">
      {records.map((record) => (
        <div
          key={record.id}
          className={`history-item ${record.id === activeId ? "active" : ""}`}
        >
          <button className="history-item-main" onClick={() => onView(record)}>
            <div className="history-item-head">
              <span className={`history-status ${record.jobState}`}>
                {record.jobState === "done" ? "✓" : record.jobState === "error" ? "✕" : "..."}
              </span>
              <strong>{record.input.productName || "未命名"}</strong>
            </div>
            <div className="history-item-meta">
              <span>{record.input.industry}</span>
              <span>{formatDate(record.createdAt)}</span>
            </div>
            <div className="history-item-provider">
              {record.providerMeta.transcriptionProvider} / {record.providerMeta.analysisProvider}
            </div>
          </button>
          <button
            className="history-delete"
            onClick={(e) => {
              e.stopPropagation();
              onDelete(record.id);
            }}
            title="删除记录"
          >
            <Trash2 size={14} />
          </button>
        </div>
      ))}
    </div>
  );
}
