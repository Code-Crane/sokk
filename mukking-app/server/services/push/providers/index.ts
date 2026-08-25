import { environment } from "../../../config/environment";
import { FcmPushProvider } from "./fcm.push-provider";
import { MockPushProvider } from "./mock.push-provider";
import { NoopPushProvider } from "./noop.push-provider";
import { PushConfigurationError, type PushProvider } from "./push-provider";

const noopPushProvider = new NoopPushProvider();
const mockPushProvider = new MockPushProvider();
const fcmPushProvider = new FcmPushProvider();

export function getPushProvider(): PushProvider {
  switch (environment.pushProvider) {
    case "noop":
      return noopPushProvider;
    case "mock":
      return mockPushProvider;
    case "fcm":
      return fcmPushProvider;
    default:
      throw new PushConfigurationError(
        `Unsupported PUSH_PROVIDER: ${environment.pushProvider}`
      );
  }
}

export function getMockPushProviderForTests(): MockPushProvider {
  return mockPushProvider;
}

export type {
  PushDeliveryResult,
  PushPayload,
  PushProvider,
  PushTarget
} from "./push-provider";
