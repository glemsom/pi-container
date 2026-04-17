/**
 * Kilo Gateway Provider for Pi
 *
 * Dynamically loads available models from Kilo API endpoint.
 * Cache models locally for at least a week, refresh on-demand.
 *
 * Usage:
 *   # Set your Kilo API token (or use KILO_API_TOKEN env var)
 *   export KILO_API_TOKEN="your-token-here"
 *
 *   # Run pi with this extension
 *   pi -e ~/.pi/agent/extensions/kilo-gateway.ts
 *
 *   # Or copy to extensions directory for auto-discovery
 *   cp kilo-gateway.ts ~/.pi/agent/extensions/
 *
 * Then use /model to select a kilo model.
 * 
 * Commands:
 *   /kilo-refresh - Fetch latest models from Kilo API and update provider
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import type { Api } from "@mariozechner/pi-ai";
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { dirname } from "node:path";
import { homedir } from "node:os";

interface KiloModelInfo {
  id: string;
  name?: string;
  pricing?: {
    prompt?: string;
    completion?: string;
    image?: string;
  };
  context_window?: number;
  max_output_tokens?: number;
}

interface KiloModelsResponse {
  data?: KiloModelInfo[];
}

interface CachedModels {
  models: any[];
  cachedAt: number;  // Unix timestamp ms
}

// Cache file path
const CACHE_DIR = `${homedir()}/.pi/agent/cache`;
const CACHE_FILE = `${CACHE_DIR}/kilo-gateway.json`;

// Cache duration: 7 days in ms
const CACHE_DURATION_MS = 7 * 24 * 60 * 60 * 1000;

/**
 * Convert Kilo API model to pi provider model format
 */
function convertKiloModel(kiloModel: KiloModelInfo): any {
  const id = kiloModel.id;
  const name = kiloModel.name || id;

  // Determine if model supports reasoning based on name patterns
  const reasoning = /opus|sonnet|thinking|reasoning|pro/i.test(name);

  // Determine input types
  const input = /vision|image|multimodal/i.test(name) ? ["text", "image"] : ["text"];

  // Parse cost from pricing if available (default to 0 if not specified)
  // Kilo pricing is in dollars per 1M tokens
  const cost = {
    input: kiloModel.pricing?.prompt ? parseFloat(kiloModel.pricing.prompt) : 0,
    output: kiloModel.pricing?.completion ? parseFloat(kiloModel.pricing.completion) : 0,
    cacheRead: 0,
    cacheWrite: 0,
  };

  const contextWindow = kiloModel.context_window || 128000;
  const maxTokens = kiloModel.max_output_tokens || 16384;

  return {
    id,
    name: `${name} (Kilo)`,
    reasoning,
    input,
    cost,
    contextWindow,
    maxTokens,
  };
}

/**
 * Fetch available models from Kilo Gateway API
 */
function fetchKiloModels(apiKey: string): Promise<any[]> {
  return new Promise((resolve) => {
    fetch("https://api.kilo.ai/api/gateway/models", {
      method: "GET",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
    })
    .then((response) => {
      if (!response.ok) {
        console.error(`Kilo API error: ${response.status} ${response.statusText}`);
        return null;
      }
      return response.json() as Promise<KiloModelsResponse>;
    })
    .then((data) => {
      if (data?.data) {
        resolve(data.data.map(convertKiloModel));
      } else {
        resolve(null);
      }
    })
    .catch((error) => {
      console.error("Failed to fetch Kilo models:", error instanceof Error ? error.message : error);
      resolve(null);
    });
  });
}

/**
 * Load cached models from file
 */
async function loadCachedModels(): Promise<CachedModels | null> {
  try {
    const content = await readFile(CACHE_FILE, "utf8");
    return JSON.parse(content) as CachedModels;
  } catch {
    return null;
  }
}

/**
 * Save models to cache file
 */
async function saveCachedModels(models: any[]): Promise<void> {
  try {
    await mkdir(dirname(CACHE_FILE), { recursive: true });
    const cached: CachedModels = {
      models,
      cachedAt: Date.now(),
    };
    await writeFile(CACHE_FILE, JSON.stringify(cached, null, 2), "utf8");
  } catch (error) {
    console.error("Failed to save cached models:", error instanceof Error ? error.message : error);
  }
}

/**
 * Check if cache is still valid (less than a week old)
 */
function isCacheValid(cached: CachedModels | null): boolean {
  if (!cached || !cached.cachedAt) return false;
  return Date.now() - cached.cachedAt < CACHE_DURATION_MS;
}

export default async function (pi: ExtensionAPI) {
  const apiKey = process.env.KILO_API_TOKEN;

  // Register Kilo as a new provider with a default model
  // This makes "kilo/free" available immediately for --models scoping
  pi.registerProvider("kilo", {
    baseUrl: "https://api.kilo.ai/api/gateway",
    apiKey: "KILO_API_TOKEN",
    api: "openai-completions" as Api,
    headers: {
      "x-kilo-client": "pi-agent",
    },
    // Default model available immediately - more models loaded async after
    models: [
      {
        id: "kilo-auto/free",
        name: "Kilo Free",
        reasoning: false,
        input: ["text"],
        cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
        contextWindow: 128000,
        maxTokens: 16384,
      },
    ],
  });

  // Register command to refresh models from API
  pi.registerCommand("kilo-refresh", {
    description: "Fetch latest models from Kilo API and update provider",
    handler: async (_args, ctx) => {
      const apiKey = process.env.KILO_API_TOKEN;
      
      if (!apiKey) {
        ctx.ui.notify("KILO_API_TOKEN not set in environment", "error");
        return;
      }

      ctx.ui.notify("Fetching models from Kilo API...", "info");

      try {
        const models = await fetchKiloModels(apiKey);
        
        if (models && models.length > 0) {
          // Save to cache
          await saveCachedModels(models);
          
          // Re-register provider with new models
          pi.registerProvider("kilo", {
            baseUrl: "https://api.kilo.ai/api/gateway",
            apiKey: "KILO_API_TOKEN",
            api: "openai-completions" as Api,
            headers: {
              "x-kilo-client": "pi-agent",
            },
            models,
          });
          
          ctx.ui.notify(`Loaded ${models.length} models from Kilo API`, "success");
          
          // Log models for debugging
          const modelNames = models.map(m => m.name).join(", ");
          console.log(`Kilo models: ${modelNames}`);
        } else {
          ctx.ui.notify("No models returned from Kilo API", "warning");
        }
      } catch (error) {
        ctx.ui.notify(`Failed to fetch models: ${error instanceof Error ? error.message : error}`, "error");
      }
    },
  });

  // Load models on startup
  async function loadModels() {
    const apiKey = process.env.KILO_API_TOKEN;
    
    if (!apiKey) {
      console.log("Kilo Gateway: KILO_API_TOKEN not set. Use /kilo-refresh after setting it.");
      return;
    }

    // Try to load from cache first
    const cached = await loadCachedModels();
    
    if (isCacheValid(cached)) {
      console.log(`Kilo Gateway: Using cached models from ${new Date(cached!.cachedAt).toISOString()}`);
      
      // Re-register with cached models
      pi.registerProvider("kilo", {
        baseUrl: "https://api.kilo.ai/api/gateway",
        apiKey: "KILO_API_TOKEN",
        api: "openai-completions" as Api,
        headers: {
          "x-kilo-client": "pi-agent",
        },
        models: cached!.models,
      });
      
      // Check if cache is stale (older than 6 days), refresh in background
      const age = Date.now() - cached!.cachedAt;
      const daysOld = Math.floor(age / (24 * 60 * 60 * 1000));
      if (daysOld >= 6) {
        console.log(`Kilo Gateway: Cache is ${daysOld} days old, refreshing in background...`);
        fetchKiloModels(apiKey).then(async (models) => {
          if (models && models.length > 0) {
            await saveCachedModels(models);
            pi.registerProvider("kilo", {
              baseUrl: "https://api.kilo.ai/api/gateway",
              apiKey: "KILO_API_TOKEN",
              api: "openai-completions" as Api,
              headers: {
                "x-kilo-client": "pi-agent",
              },
              models,
            });
            console.log(`Kilo Gateway: Background refresh complete (${models.length} models)`);
          }
        }).catch((err) => {
          console.log(`Kilo Gateway: Background refresh failed: ${err}`);
        });
      }
      return;
    }

    // No valid cache, fetch from API
    console.log("Kilo Gateway: No valid cache, fetching from API...");
    fetchKiloModels(apiKey).then(async (models) => {
      if (models && models.length > 0) {
        await saveCachedModels(models);
        pi.registerProvider("kilo", {
          baseUrl: "https://api.kilo.ai/api/gateway",
          apiKey: "KILO_API_TOKEN",
          api: "openai-completions" as Api,
          headers: {
            "x-kilo-client": "pi-agent",
          },
          models,
        });
        console.log(`Kilo Gateway: Loaded ${models.length} models from API`);
      } else {
        console.log("Kilo Gateway: No models returned from API");
      }
    }).catch((err) => {
      console.log(`Kilo Gateway: Failed to fetch models: ${err}`);
    });
  }

  // Wait for models to load before returning
  // This ensures provider is registered with full model list before model scope resolution
  await loadModels();
}