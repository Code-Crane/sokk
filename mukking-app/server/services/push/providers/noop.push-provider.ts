import type {
  PushDeliveryResult,
  PushPayload,
  PushProvider,
  PushTarget
} from "./push-provider";

export class NoopPushProvider implements PushProvider {
  readonly name = "noop" as const;

  async sendBatch(
    targets: PushTarget[],
    _payload: PushPayload
  ): Promise<PushDeliveryResult[]> {
    return targets.map((target) => ({
      deviceId: target.deviceId,
      status: "skipped" as const
    }));
  }
}
