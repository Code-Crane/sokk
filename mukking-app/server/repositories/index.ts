import type { RepositoryRegistry } from "./interfaces/repository-registry";
import { environment } from "../config/environment";
import { memoryRepositories } from "./memory";
import { supabaseAdminRepository } from "./supabase/admin.supabase.repository";
import { supabaseAuthRepository } from "./supabase/auth.supabase.repository";
import { supabaseBlockRepository } from "./supabase/block.supabase.repository";
import { supabaseChatRepository } from "./supabase/chat.supabase.repository";
import { supabaseMatchingRepository } from "./supabase/matching.supabase.repository";
import { supabaseNotificationRepository } from "./supabase/notification.supabase.repository";
import { supabasePushDeviceRepository } from "./supabase/push-device.supabase.repository";
import { supabaseRatingRepository } from "./supabase/rating.supabase.repository";
import { supabaseReportRepository } from "./supabase/report.supabase.repository";
import { supabaseRestaurantFavoriteRepository } from "./supabase/restaurant-favorite.supabase.repository";
import { supabaseRestaurantRepository } from "./supabase/restaurant.supabase.repository";
import { supabaseSanctionRepository } from "./supabase/sanction.supabase.repository";
import { supabaseUserRepository } from "./supabase/user.supabase.repository";
import { supabaseVerificationRepository } from "./supabase/verification.supabase.repository";

import { supabasePetRepository } from "./supabase/pet.supabase.repository";
const useSupabaseRepositories = environment.repositoryProvider === "supabase";

export const repositories: RepositoryRegistry = {
  ...memoryRepositories,
  pets: useSupabaseRepositories ? supabasePetRepository : memoryRepositories.pets,
  admin: useSupabaseRepositories
    ? supabaseAdminRepository
    : memoryRepositories.admin,
  auth:
    environment.authProvider === "supabase"
      ? supabaseAuthRepository
      : memoryRepositories.auth,
  blocks: useSupabaseRepositories
    ? supabaseBlockRepository
    : memoryRepositories.blocks,
  chat: useSupabaseRepositories
    ? supabaseChatRepository
    : memoryRepositories.chat,
  matching: useSupabaseRepositories
    ? supabaseMatchingRepository
    : memoryRepositories.matching,
  notifications: useSupabaseRepositories
    ? supabaseNotificationRepository
    : memoryRepositories.notifications,
  pushDevices: useSupabaseRepositories
    ? supabasePushDeviceRepository
    : memoryRepositories.pushDevices,
  rating: useSupabaseRepositories
    ? supabaseRatingRepository
    : memoryRepositories.rating,
  reports: useSupabaseRepositories
    ? supabaseReportRepository
    : memoryRepositories.reports,
  restaurantFavorites: useSupabaseRepositories
    ? supabaseRestaurantFavoriteRepository
    : memoryRepositories.restaurantFavorites,
  restaurants: useSupabaseRepositories
    ? supabaseRestaurantRepository
    : memoryRepositories.restaurants,
  sanctions: useSupabaseRepositories
    ? supabaseSanctionRepository
    : memoryRepositories.sanctions,
  users: useSupabaseRepositories ? supabaseUserRepository : memoryRepositories.users,
  verification: useSupabaseRepositories
    ? supabaseVerificationRepository
    : memoryRepositories.verification
};

export type { RepositoryRegistry } from "./interfaces/repository-registry";
