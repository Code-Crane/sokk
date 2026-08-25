export interface PushTarget {
  deviceId: string;
  token: string;
}

export interface PushPayload {
  title: string;
  body: string;
  data: Record<string, string>;
}

export type PushDeliveryStatus = "sent" | "skipped" | "invalid" | "failed";

export interface PushDeliveryResult {
  deviceId: string;
  status: PushDeliveryStatus;
  errorCode?: string;
}

export interface PushProvider {
  readonly name: "noop" | "mock" | "fcm";
  sendBatch(
    targets: PushTarget[],
    payload: PushPayload
  ): Promise<PushDeliveryResult[]>;
}

export class PushConfigurationError extends Error {
  readonly code = "PUSH_CONFIGURATION_ERROR";

  constructor(message: string) {
    super(message);
    this.name = "PushConfigurationError";
  }
}
