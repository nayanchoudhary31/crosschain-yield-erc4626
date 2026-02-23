import jwt from "jsonwebtoken";
import type { Request, Response } from "express";
import dotenv from "dotenv";
import { vault } from "../indexer/contract.js";
dotenv.config();

export const adminLogin = (req: Request, resp: Response) => {
  try {
    const { username, password } = req.body;

    if (
      username !== process.env.ADMIN_USERNAME ||
      password !== process.env.ADMIN_PASSWORD
    ) {
      return resp.status(401).json({
        success: false,
        message: "Invalid credentials",
      });
    }

    const token = jwt.sign(
      { id: "admin", role: "ADMIN" },
      process.env.JWT_SECRET!,
      { expiresIn: "2h" },
    );

    return resp.status(200).json({
      success: true,
      token,
    });
  } catch (error) {
    return resp.status(500).json({
      success: false,
      message: "Internal server error",
    });
  }
};

export const pauseVault = async (_req: Request, res: Response) => {
  try {
    const tx = await vault.getFunction("pause")();
    await tx.wait();

    return res.status(200).json({
      success: true,
      message: "Vault paused successfully",
      txHash: tx.hash,
    });
  } catch (error: any) {
    console.error("Pause error:", error.reason || error);

    return res.status(500).json({
      success: false,
      message: error.reason || "Failed to pause vault",
    });
  }
};

export const unpauseVault = async (_req: Request, res: Response) => {
  try {
    const tx = await vault.getFunction("unpause")();
    await tx.wait();

    return res.status(200).json({
      success: true,
      message: "Vault unpaused successfully",
      txHash: tx.hash,
    });
  } catch (error: any) {
    return res.status(500).json({
      success: false,
      message: error?.reason || "Failed to unpause vault",
    });
  }
};

export const updateCap = async (req: Request, res: Response) => {
  try {
    const { newCap } = req.body;

    if (!newCap) {
      return res.status(400).json({
        success: false,
        message: "newCap is required",
      });
    }

    const tx = await vault.getFunction("updateCap")(newCap);
    await tx.wait();

    return res.status(200).json({
      success: true,
      message: "Deposit cap updated successfully",
      txHash: tx.hash,
    });
  } catch (error: any) {
    return res.status(500).json({
      success: false,
      message: error?.reason || "Failed to update cap",
    });
  }
};

export const simulateYield = async (req: Request, res: Response) => {
  try {
    const { amount } = req.body;

    if (!amount) {
      return res.status(400).json({
        success: false,
        message: "amount is required",
      });
    }

    const tx = await vault.getFunction("simulateYield")(amount);
    await tx.wait();

    return res.status(200).json({
      success: true,
      message: "Yield simulated successfully",
      txHash: tx.hash,
    });
  } catch (error: any) {
    return res.status(500).json({
      success: false,
      message: error?.reason || "Failed to simulate yield",
    });
  }
};
