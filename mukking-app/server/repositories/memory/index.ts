import type { RepositoryRegistry } from "../interfaces/repository-registry";
import { memoryAdminRepository } from "./admin.memory.repository";
import { memoryAuthRepository } from "./auth.memory.repository";
import { memoryBlockRepository } from "./block.memory.repository";
import { memoryChatRepository } from "./chat.memory.repository";
import { memoryLocationRepository } from "./location.memory.repository";
import { memoryMatchingRepository } from "./matching.memory.repository";
import { memoryNotificationRepository } from "./notification.memory.repository";
import { memoryPushDeviceRepository } from "./push-device.memory.repository";
import { memoryRatingRepository } from "./rating.memory.repository";
import { memoryReportRepository } from "./report.memory.repository";
import { memoryRestaurantFavoriteRepository } from "./restaurant-favorite.memory.repository";
import { memoryRestaurantRepository } from "./restaurant.memory.repository";
import { memorySanctionRepository } from "./sanction.memory.repository";
import { memoryUserRepository } from "./user.memory.repository";
import { memoryVerificationRepository } from "./verification.memory.repository";

import { memoryPetRepository } from "./pet.memory.repository";
export const memoryRepositories: RepositoryRegistry = {
  pets: memoryPetRepository,
  admin: memoryAdminRepository,
  auth: memoryAuthRepository,
  blocks: memoryBlockRepository,
  chat: memoryChatRepository,
  location: memoryLocationRepository,
  matching: memoryMatchingRepository,
  notifications: memoryNotificationRepository,
  pushDevices: memoryPushDeviceRepository,
  rating: memoryRatingRepository,
  reports: memoryReportRepository,
  restaurantFavorites: memoryRestaurantFavoriteRepository,
  restaurants: memoryRestaurantRepository,
  sanctions: memorySanctionRepository,
  users: memoryUserRepository,
  verification: memoryVerificationRepository
};
