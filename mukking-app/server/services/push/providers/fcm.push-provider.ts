import {
  applicationDefault,
  cert,
  getApps,
  initializeApp,
  type App
} from "firebase-admin/app";
import { getMessaging } from "firebase-admin/messaging";
import { environment } from "../../../config/environment";
import {
  PushConfigurationError,
  type PushDeliveryResult,
  type PushPayload,
  type PushProvider,
  type PushTarget
} from "./push-provider";

const FIREBASE_APP_NAME = "mukking-push";
const FCM_BATCH_LIMIT = 500;
const INVALID_TOKEN_CODES = new Set([
  "messaging/invalid-registration-token",
  "messaging/registration-token-not-registered"
]);

let firebaseApp: App | null = null;

function getFirebaseApp(): App {
  if (firebaseApp) return firebaseApp;

  const existing = getApps().find((app) => app.name === FIREBASE_APP_NAME);
  if (existing) {
    firebaseApp = existing;
    return existing;
  }

  const hasExplicitCredentials = Boolean(
    environment.firebaseProjectId &&
      environment.firebaseClientEmail &&
      environment.firebasePrivateKey
  );
  const useApplicationDefault =
    environment.firebaseUseApplicationDefaultCredentials ||
    Boolean(process.env.GOOGLE_APPLICATION_CREDENTIALS);

  if (!hasExplicitCredentials && !useApplicationDefault) {
    throw new PushConfigurationError(
      "FCM push is selected but Firebase credentials are missing. Configure Application Default Credentials or the server-only FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, and FIREBASE_PRIVATE_KEY values."
    );
  }

  firebaseApp = initializeApp(
    {
      credential: hasExplicitCredentials
        ? cert({
            projectId: environment.firebaseProjectId,
            clientEmail: environment.firebaseClientEmail,
            privateKey: environment.firebasePrivateKey.replace(/\\n/g, "\n")
          })
        : applicationDefault(),
      ...(environment.firebaseProjectId
        ? { projectId: environment.firebaseProjectId }
        : {})
    },
    FIREBASE_APP_NAME
  );

  return firebaseApp;
}

function chunks<T>(values: T[], size: number): T[][] {
  const result: T[][] = [];
  for (let index = 0; index < values.length; index += size) {
    result.push(values.slice(index, index + size));
  }
  return result;
}

export class FcmPushProvider implements PushProvider {
  readonly name = "fcm" as const;

  async sendBatch(
    targets: PushTarget[],
    payload: PushPayload
  ): Promise<PushDeliveryResult[]> {
    const messaging = getMessaging(getFirebaseApp());
    const results: PushDeliveryResult[] = [];

    for (const batch of chunks(targets, FCM_BATCH_LIMIT)) {
      try {
        const response = await messaging.sendEachForMulticast({
          tokens: batch.map((target) => target.token),
          notification: { title: payload.title, body: payload.body },
          data: payload.data
        });

        response.responses.forEach((item, index) => {
          const target = batch[index];
          const errorCode = item.error?.code;
          results.push({
            deviceId: target.deviceId,
            status: item.success
              ? "sent"
              : errorCode && INVALID_TOKEN_CODES.has(errorCode)
                ? "invalid"
                : "failed",
            ...(errorCode ? { errorCode } : {})
          });
        });
      } catch (error) {
        const errorCode =
          error && typeof error === "object" && "code" in error
            ? String(error.code)
            : "messaging/batch-failed";
        results.push(
          ...batch.map((target) => ({
            deviceId: target.deviceId,
            status: "failed" as const,
            errorCode
          }))
        );
      }
    }

    return results;
  }
}
