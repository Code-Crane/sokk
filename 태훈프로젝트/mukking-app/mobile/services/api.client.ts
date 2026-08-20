const API_BASE_URL =
  process.env.EXPO_PUBLIC_API_URL?.replace(/\/$/, "") ?? "http://localhost:4000";

let authToken: string | null = null;

export class ApiClientError extends Error {
  constructor(message: string, public readonly statusCode: number) {
    super(message);
  }
}

export function setAuthToken(token: string | null): void {
  authToken = token;
}

export async function apiRequest<T>(
  path: string,
  options: RequestInit = {}
): Promise<T> {
  const optionHeaders = options.headers as Record<string, string> | undefined;
  const headers: Record<string, string> = {
    "Content-Type": "application/json"
  };

  if (authToken) {
    headers.Authorization = `Bearer ${authToken}`;
  }

  const response = await fetch(`${API_BASE_URL}${path}`, {
    ...options,
    headers: {
      ...headers,
      ...(optionHeaders ?? {})
    }
  });

  const payload = await response.json().catch(() => undefined);

  if (!response.ok) {
    throw new ApiClientError(
      payload?.message ?? "Request failed.",
      response.status
    );
  }

  return payload as T;
}
