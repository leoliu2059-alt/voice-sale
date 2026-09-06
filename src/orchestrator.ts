import type {
  TranscriptionProvider,
  ReviewAnalysisProvider,
  DiarizationProvider,
  TranscriptResult,
  ReviewResult,
  ReviewInput,
  AppConfig,
} from "./types";
import {
  mockTranscriptionProvider,
  openaiTranscriptionProvider,
  templateAnalysisProvider,
  openaiAnalysisProvider,
  noopDiarizationProvider,
} from "./providers";
import { getEffectiveConfig } from "./config";

// ── Provider registry ──

const transcriptionProviders: Record<string, TranscriptionProvider> = {
  mock: mockTranscriptionProvider,
  openai: openaiTranscriptionProvider,
};

const analysisProviders: Record<string, ReviewAnalysisProvider> = {
  template: templateAnalysisProvider,
  openai: openaiAnalysisProvider,
};

const diarizationProviders: Record<string, DiarizationProvider> = {
  noop: noopDiarizationProvider,
};

// ── Resolve providers from config ──

function resolveProviders(config: AppConfig) {
  const transcription =
    transcriptionProviders[config.transcriptionProvider] ?? mockTranscriptionProvider;

  const analysis =
    analysisProviders[config.analysisProvider] ?? templateAnalysisProvider;

  const diarization = diarizationProviders["noop"];

  return { transcription, analysis, diarization };
}

// ── Orchestrator ──

export type OrchestratorEvents = {
  onProgress: (stage: "uploading" | "transcribing" | "analyzing", percent: number) => void;
};

export async function runReviewPipeline(
  input: ReviewInput,
  events?: OrchestratorEvents,
): Promise<{ transcript: TranscriptResult; review: ReviewResult }> {
  const config = getEffectiveConfig();
  const { transcription, analysis, diarization } = resolveProviders(config);

  const hasAudio = !!input.audioFile;

  let transcript: TranscriptResult;

  if (hasAudio && config.enableRealAI) {
    // ── Real AI pipeline ──
    events?.onProgress("uploading", 20);

    // Step 1: Transcribe
    events?.onProgress("transcribing", 40);
    const rawTranscript = await transcription.transcribe(input.audioFile!);

    // Step 2: Diarize (skip if transcription already includes speaker labels)
    const hasDiarization = rawTranscript.utterances.length > 0 && rawTranscript.utterances.some((u) => u.speaker);
    if (!hasDiarization) {
      const diarized = await diarization.diarize(input.audioFile!);
      if (diarized.utterances.length > 0) {
        transcript = diarized;
      } else {
        transcript = rawTranscript;
      }
    } else {
      transcript = rawTranscript;
    }

    // Step 3: Analyze
    events?.onProgress("analyzing", 70);
    const review = await analysis.analyze(transcript, input);
    events?.onProgress("analyzing", 100);

    return { transcript, review };
  }

  // ── Demo / template pipeline ──
  events?.onProgress("uploading", 28);
  await delay(450);

  events?.onProgress("transcribing", 62);
  // Even without audio, generate a demo transcript
  transcript = await transcription.transcribe(
    input.audioFile ?? new File([], "demo.mp3"),
  );

  events?.onProgress("analyzing", 84);
  const review = await analysis.analyze(transcript, input);

  events?.onProgress("analyzing", 100);

  return { transcript, review };
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
