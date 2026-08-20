import express, { type ErrorRequestHandler } from "express";
import { routes } from "./routes";
import {
  createCorsMiddleware,
  createHelmetMiddleware
} from "./middleware/security.middleware";

export const app = express();

app.use(createHelmetMiddleware());
app.use(createCorsMiddleware());
app.use(express.json());
app.use("/api", routes);

const errorHandler: ErrorRequestHandler = (error, _request, response, _next) => {
  const statusCode = typeof error.statusCode === "number" ? error.statusCode : 500;
  const message = error instanceof Error ? error.message : "Unexpected server error";

  response.status(statusCode).json({ message });
};

app.use(errorHandler);
