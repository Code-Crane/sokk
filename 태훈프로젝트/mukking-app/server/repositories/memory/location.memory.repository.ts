import type { GeoPoint, MatchingPost } from "../../../shared/types";
import { db } from "../../models/inMemoryDb";
import type {
  LocationRepository,
  RadiusSearchInput,
  SanitizedLocation
} from "../interfaces/location.repository";

const EARTH_RADIUS_METERS = 6371_000;

function toRadians(value: number): number {
  return (value * Math.PI) / 180;
}

function calculateHaversineDistanceMeters(from: GeoPoint, to: GeoPoint): number {
  const latitudeDelta = toRadians(to.latitude - from.latitude);
  const longitudeDelta = toRadians(to.longitude - from.longitude);
  const fromLatitude = toRadians(from.latitude);
  const toLatitude = toRadians(to.latitude);

  const a =
    Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(fromLatitude) *
      Math.cos(toLatitude) *
      Math.sin(longitudeDelta / 2) ** 2;

  return 2 * EARTH_RADIUS_METERS * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export const memoryLocationRepository: LocationRepository = {
  async findPostsWithinRadius(input: RadiusSearchInput) {
    const posts = Array.from(db.posts.values())
      .filter((post) => (input.status ? post.status === input.status : true))
      .map((post) => ({
        post,
        distanceMeters: post.location
          ? calculateHaversineDistanceMeters(input.center, post.location)
          : undefined
      }))
      .filter((entry) =>
        entry.distanceMeters === undefined
          ? Boolean(input.includeWithoutLocation)
          : entry.distanceMeters <= input.radiusMeters
      )
      .sort((left, right) => {
        if (left.distanceMeters === undefined) {
          return 1;
        }

        if (right.distanceMeters === undefined) {
          return -1;
        }

        return left.distanceMeters - right.distanceMeters;
      });

    const offset = input.offset ?? 0;
    const limit = input.limit ?? posts.length;

    return posts.slice(offset, offset + limit);
  },

  async calculateDistanceMeters(from, to) {
    return calculateHaversineDistanceMeters(from, to);
  },

  async updatePostLocation(postId, location) {
    const post = db.posts.get(postId);

    if (!post) {
      throw Object.assign(new Error("Matching post not found."), { statusCode: 404 });
    }

    const updated: MatchingPost = {
      ...post,
      location: location ?? undefined,
      updatedAt: new Date().toISOString()
    };

    db.posts.set(postId, updated);
  },

  async sanitizePostLocation(post, viewerId): Promise<SanitizedLocation> {
    return {
      address: post.address,
      exactLocation:
        viewerId && [post.authorId, ...post.participantIds].includes(viewerId)
          ? post.location
          : undefined,
      canViewExactLocation: Boolean(
        viewerId && [post.authorId, ...post.participantIds].includes(viewerId)
      )
    };
  }
};
