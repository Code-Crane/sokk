import type { UserNotification } from "../../../shared/types";
import { nowIso } from "../../../shared/utils/date";
import { repositories } from "../../repositories";
import { getPushProvider } from "./providers";

export interface PushDispatchSummary {
  notifications: number;
  noDevice: number;
  sent: number;
  skipped: number;
  failed: number;
  invalidDisabled: number;
}

function toPayload(notification: UserNotification) {
  return {
    title: notification.title,
    body: notification.body,
    data: {
      notificationId: notification.id,
      type: notification.type,
      ...(notification.restaurantId
        ? { restaurantId: notification.restaurantId }
        : {}),
      ...(notification.matchingPostId
        ? { matchingPostId: notification.matchingPostId }
        : {})
    }
  };
}

export async function dispatchNotificationsBestEffort(
  notifications: UserNotification[]
): Promise<PushDispatchSummary> {
  const summary: PushDispatchSummary = {
    notifications: notifications.length,
    noDevice: 0,
    sent: 0,
    skipped: 0,
    failed: 0,
    invalidDisabled: 0
  };

  for (const notification of notifications) {
    try {
      const devices = await repositories.pushDevices.listActiveDevicesByUser(
        notification.userId
      );

      if (devices.length === 0) {
        summary.noDevice += 1;
        continue;
      }

      const provider = getPushProvider();
      const results = await provider.sendBatch(
        devices.map((device) => ({
          deviceId: device.id,
          token: device.pushToken
        })),
        toPayload(notification)
      );

      for (const result of results) {
        if (result.status === "sent") summary.sent += 1;
        if (result.status === "skipped") summary.skipped += 1;
        if (result.status === "failed") summary.failed += 1;

        if (result.status === "invalid") {
          const disabled = await repositories.pushDevices.disableDevice(
            result.deviceId,
            nowIso()
          );
          if (disabled) summary.invalidDisabled += 1;
        }
      }

      const failedCount = results.filter((result) => result.status === "failed").length;
      if (failedCount > 0) {
        console.error("[push] Some deliveries failed and remain eligible for a later retry.", {
          notificationId: notification.id,
          provider: provider.name,
          failedCount
        });
      }
    } catch (error) {
      summary.failed += 1;
      console.error("[push] Dispatch failed after notification persistence.", {
        notificationId: notification.id,
        errorName: error instanceof Error ? error.name : "UnknownError"
      });
    }
  }

  return summary;
}
