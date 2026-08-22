import type { NextFunction, Request, Response } from "express";
import type { RestaurantListQuery } from "../../shared/types";
import type { AuthenticatedRequest } from "../models/http.types";
import {
  addRestaurantFavorite,
  createRestaurant,
  getRestaurant,
  listMyRestaurantFavorites,
  listRestaurants,
  removeRestaurantFavorite
} from "../services/restaurant/restaurant.service";

export async function createRestaurantController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    response.status(201).json(await createRestaurant(request.body));
  } catch (error) {
    next(error);
  }
}

export async function listRestaurantsController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;
    response.json(
      await listRestaurants(
        authenticatedRequest.userId,
        request.query as unknown as RestaurantListQuery
      )
    );
  } catch (error) {
    next(error);
  }
}

export async function getRestaurantController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;
    response.json(
      await getRestaurant(authenticatedRequest.userId, request.params.restaurantId)
    );
  } catch (error) {
    next(error);
  }
}

export async function addRestaurantFavoriteController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;
    response.status(201).json(
      await addRestaurantFavorite(authenticatedRequest.userId, request.params.restaurantId)
    );
  } catch (error) {
    next(error);
  }
}

export async function removeRestaurantFavoriteController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;
    response.json(
      await removeRestaurantFavorite(authenticatedRequest.userId, request.params.restaurantId)
    );
  } catch (error) {
    next(error);
  }
}

export async function listMyRestaurantFavoritesController(
  request: Request,
  response: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authenticatedRequest = request as AuthenticatedRequest;
    response.json(await listMyRestaurantFavorites(authenticatedRequest.userId));
  } catch (error) {
    next(error);
  }
}
