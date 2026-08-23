import type { AdminRepository } from "./admin.repository";
import type { AuthRepository } from "./auth.repository";
import type { BlockRepository } from "./block.repository";
import type { ChatRepository } from "./chat.repository";
import type { LocationRepository } from "./location.repository";
import type { MatchingRepository } from "./matching.repository";
import type { NotificationRepository } from "./notification.repository";
import type { RatingRepository } from "./rating.repository";
import type { ReportRepository } from "./report.repository";
import type { RestaurantFavoriteRepository } from "./restaurant-favorite.repository";
import type { RestaurantRepository } from "./restaurant.repository";
import type { SanctionRepository } from "./sanction.repository";
import type { UserRepository } from "./user.repository";
import type { VerificationRepository } from "./verification.repository";

export interface RepositoryRegistry {
  admin: AdminRepository;
  auth: AuthRepository;
  blocks: BlockRepository;
  chat: ChatRepository;
  location: LocationRepository;
  matching: MatchingRepository;
  notifications: NotificationRepository;
  rating: RatingRepository;
  reports: ReportRepository;
  restaurantFavorites: RestaurantFavoriteRepository;
  restaurants: RestaurantRepository;
  sanctions: SanctionRepository;
  users: UserRepository;
  verification: VerificationRepository;
}
