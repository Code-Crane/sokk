import type {
  PushDevicePlatform,
  PushDeviceResponse,
  RegisterPushDeviceInput,
  UserPushDevice
} from "../../../shared/types";
import { nowIso } from "../../../shared/utils/date";
import { repositories } from "../../repositories";

const ALLOWED_PLATFORMS = new Set<PushDevicePlatform>([
  "android",
  "ios",
  "web"
]);

function invalid(message: string): never {
  throw Object.assign(new Error(message), { statusCode: 400 });
}

function toResponse(device: UserPushDevice): PushDeviceResponse {
  return {
    id: device.id,
    provider: device.provider,
    platform: device.platform,
    enabled: device.enabled,
    createdAt: device.createdAt,
    updatedAt: device.updatedAt,
    lastSeenAt: device.lastSeenAt
  };
}

function validateInput(input: RegisterPushDeviceInput): {
  token: string;
  platform: PushDevicePlatform;
} {
  const token = typeof input.token === "string" ? input.token.trim() : "";
  if (token.length < 16 || token.length > 4096 || /\s/.test(token)) {
    return invalid("token must be 16 to 4096 non-whitespace characters.");
  }

  if (!ALLOWED_PLATFORMS.has(input.platform)) {
    return invalid("platform must be android, ios, or web.");
  }

  return { token, platform: input.platform };
}

export async function registerPushDevice(
  userId: string,
  input: RegisterPushDeviceInput
): Promise<PushDeviceResponse> {
  const validated = validateInput(input);
  const device = await repositories.pushDevices.registerDevice({
    userId,
    provider: "fcm",
    platform: validated.platform,
    pushToken: validated.token,
    observedAt: nowIso()
  });

  return toResponse(device);
}

export async function disablePushDevice(
  userId: string,
  deviceId: string
): Promise<PushDeviceResponse> {
  const device = await repositories.pushDevices.findById(deviceId);

  if (!device) {
    throw Object.assign(new Error("Push device not found."), { statusCode: 404 });
  }

  if (device.userId !== userId) {
    throw Object.assign(new Error("You cannot disable another user's device."), {
      statusCode: 403
    });
  }

  const disabled = await repositories.pushDevices.disableDevice(device.id, nowIso());
  if (!disabled) {
    throw Object.assign(new Error("Push device not found."), { statusCode: 404 });
  }

  return toResponse(disabled);
}
