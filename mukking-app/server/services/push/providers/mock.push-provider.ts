import type {
  PushDeliveryResult,
  PushPayload,
  PushProvider,
  PushTarget
} from "./push-provider";

export interface MockPushDispatch {
  deviceIds: string[];
  payload: PushPayload;
}

export class MockPushProvider implements PushProvider {
  readonly name = "mock" as const;
  readonly dispatches: MockPushDispatch[] = [];

  reset(): void {
    this.dispatches.length = 0;
  }

  async sendBatch(
    targets: PushTarget[],
    payload: PushPayload
  ): Promise<PushDeliveryResult[]> {
    this.dispatches.push({
      deviceIds: targets.map((target) => target.deviceId),
      payload: { ...payload, data: { ...payload.data } }
    });

    return targets.map((target) => {
      if (target.token.startsWith("mock-invalid-")) {
        return {
          deviceId: target.deviceId,
          status: "invalid" as const,
          errorCode: "messaging/registration-token-not-registered"
        };
      }

      if (target.token.startsWith("mock-transient-")) {
        return {
          deviceId: target.deviceId,
          status: "failed" as const,
          errorCode: "messaging/server-unavailable"
        };
      }

      return { deviceId: target.deviceId, status: "sent" as const };
    });
  }
}
