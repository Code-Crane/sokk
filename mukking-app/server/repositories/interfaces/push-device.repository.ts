import type {
  PushDevicePlatform,
  PushDeviceProvider,
  UserPushDevice
} from "../../../shared/types";

export interface RegisterPushDeviceRepositoryInput {
  userId: string;
  provider: PushDeviceProvider;
  platform: PushDevicePlatform;
  pushToken: string;
  observedAt: string;
}

export interface PushDeviceRepository {
  registerDevice(
    input: RegisterPushDeviceRepositoryInput
  ): Promise<UserPushDevice>;
  findById(deviceId: string): Promise<UserPushDevice | null>;
  findByToken(
    provider: PushDeviceProvider,
    pushToken: string
  ): Promise<UserPushDevice | null>;
  listActiveDevicesByUser(userId: string): Promise<UserPushDevice[]>;
  disableDevice(deviceId: string, updatedAt: string): Promise<UserPushDevice | null>;
  disableToken(
    provider: PushDeviceProvider,
    pushToken: string,
    updatedAt: string
  ): Promise<UserPushDevice | null>;
}
