import { Router } from "express";
import {
  addRestaurantFavoriteController,
  createRestaurantController,
  discoverRestaurantsController,
  getRestaurantController,
  listMyRestaurantFavoritesController,
  listRestaurantsController,
  removeRestaurantFavoriteController
} from "../controllers/restaurant.controller";
import { authMiddleware } from "../middleware/auth.middleware";
import {
  restaurantDiscoveryRateLimit,
  restaurantWriteRateLimit
} from "../middleware/rateLimit.middleware";

export const restaurantRoutes = Router();

restaurantRoutes.use(authMiddleware);
restaurantRoutes.get("/favorites/me", listMyRestaurantFavoritesController);
restaurantRoutes.post(
  "/discover",
  restaurantDiscoveryRateLimit,
  discoverRestaurantsController
);
restaurantRoutes.post("/:restaurantId/favorite", restaurantWriteRateLimit, addRestaurantFavoriteController);
restaurantRoutes.delete("/:restaurantId/favorite", restaurantWriteRateLimit, removeRestaurantFavoriteController);
restaurantRoutes.get("/", listRestaurantsController);
restaurantRoutes.post("/", restaurantWriteRateLimit, createRestaurantController);
restaurantRoutes.get("/:restaurantId", getRestaurantController);
