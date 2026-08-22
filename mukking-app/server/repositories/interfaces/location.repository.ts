import type { GeoPoint, MatchingPost } from "../../../shared/types";
import type { RepositoryListOptions } from "./repository.types";

export interface RadiusSearchInput extends RepositoryListOptions {
  center: GeoPoint;
  radiusMeters: number;
  includeWithoutLocation?: boolean;
  status?: MatchingPost["status"];
}

export interface PostWithDistance {
  post: MatchingPost;
  distanceMeters?: number;
}

export interface SanitizedLocation {
  address: string;
  distanceMeters?: number;
  approximateLocation?: GeoPoint;
  exactLocation?: GeoPoint;
  canViewExactLocation: boolean;
}

export interface LocationRepository {
  findPostsWithinRadius(input: RadiusSearchInput): Promise<PostWithDistance[]>;
  calculateDistanceMeters(from: GeoPoint, to: GeoPoint): Promise<number>;
  updatePostLocation(postId: string, location: GeoPoint | null): Promise<void>;
  sanitizePostLocation(
    post: MatchingPost,
    viewerId?: string
  ): Promise<SanitizedLocation>;
}
