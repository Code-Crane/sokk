import { Router } from "express";
import {
  listChatRoomsController,
  listMessagesController,
  sendMessageController
} from "../controllers/chat.controller";
import { authMiddleware } from "../middleware/auth.middleware";

export const chatRoutes = Router();

chatRoutes.get("/rooms", authMiddleware, listChatRoomsController);
chatRoutes.get("/rooms/:roomId/messages", authMiddleware, listMessagesController);
chatRoutes.post("/rooms/:roomId/messages", authMiddleware, sendMessageController);

