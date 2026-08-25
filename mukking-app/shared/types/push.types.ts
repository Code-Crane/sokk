export type PushDeviceProvider = "fcm";

export type PushDevicePlatform = "android" | "ios" | "web";

export interface UserPushDevice {
  id: string;
  userId: string;
  provider: PushDeviceProvider;
  platform: PushDevicePlatform;
  pushToken: string;
  enabled: boolean;
  createdAt: string;
  updatedAt: string;
  lastSeenAt: string;
}

export interface RegisterPushDeviceInput {
  token: string;
  platform: PushDevicePlatform;
}

export interface PushDeviceResponse {
  id: string;
  provider: PushDeviceProvider;
  platform: PushDevicePlatform;
  enabled: boolean;
  createdAt: string;
  updatedAt: string;
  lastSeenAt: string;
}
