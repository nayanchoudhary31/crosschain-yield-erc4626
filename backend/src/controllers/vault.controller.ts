import type { Request, Response } from "express";
import prisma from "../db/db.js";

export const getVaultStats = async (_req: Request, res: Response) => {
  try {
    const stats = await prisma.vaultStats.findUnique({
      where: { id: 1 },
    });

    if (!stats) {
      return res.status(200).json({
        success: true,
        data: {
          totalDeposits: "0",
          totalWithdrawals: "0",
          totalShares: "0",
          userCount: 0,
        },
      });
    }

    return res.status(200).json({
      success: true,
      data: {
        totalDeposits: stats.totalDeposits.toString(),
        totalWithdrawals: stats.totalWithdrawals.toString(),
        totalShares: stats.totalShares.toString(),
        userCount: stats.userCount,
      },
    });
  } catch (error) {
    console.error("Vault stats error:", error);

    return res.status(500).json({
      success: false,
      message: "Internal server error",
    });
  }
};
