export function nowIso(): string {
  return new Date().toISOString();
}

export function isFutureIso(value: string): boolean {
  return new Date(value).getTime() > Date.now();
}

