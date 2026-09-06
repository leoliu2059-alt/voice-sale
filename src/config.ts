/// <reference types="vite/client" />
import type { AppConfig } from "./types";

const STORAGE_KEY = "voicesale_config";

const defaultConfig: AppConfig = {
  transcriptionProvider: "mock",
  analysisProvider: "template",
  enableRealAI: false,
};

export function loadConfig(): AppConfig {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) {
      const parsed = JSON.parse(raw) as Partial<AppConfig>;
      return { ...defaultConfig, ...parsed };
    }
  } catch {
    // fall through
  }
  return { ...defaultConfig };
}

export function saveConfig(config: AppConfig): void {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(config));
}

export function getDefaultConfig(): AppConfig {
  return { ...defaultConfig };
}

// Read environment variable overrides (Vite exposes VITE_* prefixed vars)
export function getEnvConfig(): Partial<AppConfig> {
  const overrides: Partial<AppConfig> = {};
  if (import.meta.env.VITE_TRANSCRIPTION_PROVIDER) {
    overrides.transcriptionProvider = import.meta.env.VITE_TRANSCRIPTION_PROVIDER;
  }
  if (import.meta.env.VITE_ANALYSIS_PROVIDER) {
    overrides.analysisProvider = import.meta.env.VITE_ANALYSIS_PROVIDER;
  }
  if (import.meta.env.VITE_ENABLE_REAL_AI === "true") {
    overrides.enableRealAI = true;
  }
  return overrides;
}

export function getEffectiveConfig(): AppConfig {
  const saved = loadConfig();
  const env = getEnvConfig();
  return { ...saved, ...env };
}
