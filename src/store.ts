import type {
  ReviewRecord,
  ReviewInput,
  ReviewResult,
  TranscriptResult,
  JobState,
} from "./types";

const STORAGE_KEY = "voicesale_records";

export function loadRecords(): ReviewRecord[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) {
      return JSON.parse(raw) as ReviewRecord[];
    }
  } catch {
    // fall through
  }
  return [];
}

export function saveRecords(records: ReviewRecord[]): void {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(records));
}

export function addRecord(
  input: ReviewInput,
  providerMeta: { transcriptionProvider: string; analysisProvider: string },
): ReviewRecord {
  const records = loadRecords();
  const record: ReviewRecord = {
    id: crypto.randomUUID?.() ?? `${Date.now()}-${Math.random().toString(36).slice(2)}`,
    createdAt: new Date().toISOString(),
    input: { ...input, audioFile: undefined }, // don't persist File object
    transcript: null,
    review: null,
    jobState: "idle",
    providerMeta,
  };
  records.unshift(record);
  saveRecords(records);
  return record;
}

export function updateRecord(
  id: string,
  patch: {
    transcript?: TranscriptResult | null;
    review?: ReviewResult | null;
    jobState?: JobState;
    error?: string;
  },
): ReviewRecord | null {
  const records = loadRecords();
  const idx = records.findIndex((r) => r.id === id);
  if (idx === -1) return null;
  records[idx] = { ...records[idx], ...patch };
  saveRecords(records);
  return records[idx];
}

export function deleteRecord(id: string): void {
  const records = loadRecords().filter((r) => r.id !== id);
  saveRecords(records);
}

export function getRecordById(id: string): ReviewRecord | null {
  return loadRecords().find((r) => r.id === id) ?? null;
}

// Save last input for convenience
const LAST_INPUT_KEY = "voicesale_last_input";

export function saveLastInput(input: ReviewInput): void {
  const safe = { ...input, audioFile: undefined };
  localStorage.setItem(LAST_INPUT_KEY, JSON.stringify(safe));
}

export function loadLastInput(): ReviewInput | null {
  try {
    const raw = localStorage.getItem(LAST_INPUT_KEY);
    if (raw) return JSON.parse(raw) as ReviewInput;
  } catch {
    // fall through
  }
  return null;
}
