import { createHash } from "crypto";

let counter = 0;

export function createEntityId(prefix: string): string {
  counter += 1;
  return `${prefix}_${Date.now().toString(36)}_${counter.toString(36)}`;
}

export function createProviderEntityId(
  prefix: string,
  provider: string,
  providerId: string
): string {
  const normalizedProvider = provider
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "") || "provider";
  const digest = createHash("sha256")
    .update(`${provider}:${providerId}`)
    .digest("hex")
    .slice(0, 24);

  return `${prefix}_${normalizedProvider}_${digest}`;
}

