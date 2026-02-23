import type { NextFunction, Request, Response } from "express";
import dotenv from "dotenv";
import jwt from "jsonwebtoken";
dotenv.config();

interface JwtPayload {
  userId: String;
  role: String;
}

declare global {
  namespace Express {
    interface Request {
      user?: JwtPayload;
    }
  }
}

export const authenticateJwt = (
  req: Request,
  resp: Response,
  next: NextFunction,
) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return resp.status(401).json({
        success: false,
        message: "Unauthorized: Missing token",
      });
    }

    const token = authHeader.substring(7)

    const decoded = jwt.verify(
      token,
      process.env.JWT_SECRET as string, 
    ) as JwtPayload;

    req.user = decoded;

    next();
  } catch (error) {
    return resp.status(401).json({
      success: false,
      message: "Unauthorized: Invalid token",
    });
  }
};
