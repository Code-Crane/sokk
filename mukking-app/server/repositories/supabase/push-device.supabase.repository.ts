import type {
  PushDevicePlatform,
  PushDeviceProvider,
  UserPushDevice
} from "../../../shared/types";
import { getSupabaseServiceRoleClient } from "../../config/supabase";
import { createEntityId } from "../../models/id";
import type {
  PushDeviceRepository,
  RegisterPushDeviceRepositoryInput
} from "../interfaces/push-device.repository";
import { ensureRow, throwSupabaseError } from "./helpers";

type PushDeviceRow = {
  id: string;
  user_id: string;
  provider: PushDeviceProvider;
  platform: PushDevicePlatform;
  push_token: string;
  enabled: boolean;
  created_at: string;
  updated_at: string;
  last_seen_at: string;
};

function toPushDevice(row: PushDeviceRow): UserPushDevice {
  return {
    id: row.id,
    userId: row.user_id,
    provider: row.provider,
    platform: row.platform,
    pushToken: row.push_token,
    enabled: row.enabled,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    lastSeenAt: row.last_seen_at
  };
}

async function updateExistingDevice(
  deviceId: string,
  input: RegisterPushDeviceRepositoryInput
): Promise<UserPushDevice> {
  const { data, error } = await getSupabaseServiceRoleClient()
    .from("user_push_devices")
    .update({
      user_id: input.userId,
      platform: input.platform,
      enabled: true,
      updated_at: input.observedAt,
      last_seen_at: input.observedAt
    })
    .eq("id", deviceId)
    .select("*")
    .single<PushDeviceRow>();

  if (error) throwSupabaseError(error);
  return toPushDevice(ensureRow(data, "Push device was not updated."));
}

async function findByToken(
  provider: PushDeviceProvider,
  pushToken: string
): Promise<UserPushDevice | null> {
  const { data, error } = await getSupabaseServiceRoleClient()
    .from("user_push_devices")
    .select("*")
    .eq("provider", provider)
    .eq("push_token", pushToken)
    .maybeSingle<PushDeviceRow>();

  if (error) throwSupabaseError(error);
  return data ? toPushDevice(data) : null;
}

export const supabasePushDeviceRepository: PushDeviceRepository = {
  async registerDevice(input) {
    const existing = await findByToken(input.provider, input.pushToken);
    if (existing) return updateExistingDevice(existing.id, input);

    const { data, error } = await getSupabaseServiceRoleClient()
      .from("user_push_devices")
      .insert({
        id: createEntityId("push_device"),
        user_id: input.userId,
        provider: input.provider,
        platform: input.platform,
        push_token: input.pushToken,
        enabled: true,
        created_at: input.observedAt,
        updated_at: input.observedAt,
        last_seen_at: input.observedAt
      })
      .select("*")
      .single<PushDeviceRow>();

    if (error?.code === "23505") {
      const concurrent = await findByToken(input.provider, input.pushToken);
      if (concurrent) return updateExistingDevice(concurrent.id, input);
    }
    if (error) throwSupabaseError(error);
    return toPushDevice(ensureRow(data, "Push device was not registered."));
  },

  async findById(deviceId) {
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("user_push_devices")
      .select("*")
      .eq("id", deviceId)
      .maybeSingle<PushDeviceRow>();

    if (error) throwSupabaseError(error);
    return data ? toPushDevice(data) : null;
  },

  findByToken,

  async listActiveDevicesByUser(userId) {
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("user_push_devices")
      .select("*")
      .eq("user_id", userId)
      .eq("enabled", true)
      .order("updated_at", { ascending: false })
      .returns<PushDeviceRow[]>();

    if (error) throwSupabaseError(error);
    return (data ?? []).map(toPushDevice);
  },

  async disableDevice(deviceId, updatedAt) {
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("user_push_devices")
      .update({ enabled: false, updated_at: updatedAt })
      .eq("id", deviceId)
      .select("*")
      .maybeSingle<PushDeviceRow>();

    if (error) throwSupabaseError(error);
    return data ? toPushDevice(data) : null;
  },

  async disableToken(provider, pushToken, updatedAt) {
    const { data, error } = await getSupabaseServiceRoleClient()
      .from("user_push_devices")
      .update({ enabled: false, updated_at: updatedAt })
      .eq("provider", provider)
      .eq("push_token", pushToken)
      .select("*")
      .maybeSingle<PushDeviceRow>();

    if (error) throwSupabaseError(error);
    return data ? toPushDevice(data) : null;
  }
};
