import type { UserPushDevice } from "../../../shared/types";
import { createEntityId } from "../../models/id";
import { db } from "../../models/inMemoryDb";
import type { PushDeviceRepository } from "../interfaces/push-device.repository";

function findStoredDevice(
  provider: UserPushDevice["provider"],
  pushToken: string
): UserPushDevice | null {
  return (
    Array.from(db.pushDevices.values()).find(
      (device) => device.provider === provider && device.pushToken === pushToken
    ) ?? null
  );
}

export const memoryPushDeviceRepository: PushDeviceRepository = {
  async registerDevice(input) {
    const existing = findStoredDevice(input.provider, input.pushToken);

    if (existing) {
      const updated: UserPushDevice = {
        ...existing,
        userId: input.userId,
        platform: input.platform,
        enabled: true,
        updatedAt: input.observedAt,
        lastSeenAt: input.observedAt
      };
      db.pushDevices.set(updated.id, updated);
      return updated;
    }

    const created: UserPushDevice = {
      id: createEntityId("push_device"),
      userId: input.userId,
      provider: input.provider,
      platform: input.platform,
      pushToken: input.pushToken,
      enabled: true,
      createdAt: input.observedAt,
      updatedAt: input.observedAt,
      lastSeenAt: input.observedAt
    };
    db.pushDevices.set(created.id, created);
    return created;
  },

  async findById(deviceId) {
    return db.pushDevices.get(deviceId) ?? null;
  },

  async findByToken(provider, pushToken) {
    return findStoredDevice(provider, pushToken);
  },

  async listActiveDevicesByUser(userId) {
    return Array.from(db.pushDevices.values()).filter(
      (device) => device.userId === userId && device.enabled
    );
  },

  async disableDevice(deviceId, updatedAt) {
    const existing = db.pushDevices.get(deviceId);
    if (!existing) return null;
    if (!existing.enabled) return existing;

    const updated = { ...existing, enabled: false, updatedAt };
    db.pushDevices.set(deviceId, updated);
    return updated;
  },

  async disableToken(provider, pushToken, updatedAt) {
    const existing = findStoredDevice(provider, pushToken);
    if (!existing) return null;
    return this.disableDevice(existing.id, updatedAt);
  }
};
