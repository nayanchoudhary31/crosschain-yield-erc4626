import type { Request, Response } from "express";
import { isAddress } from "ethers";
import prisma from "../db/db.js";

export const getUserPosition = async (req: Request, res: Response) => {
  try {
    const { address } = req.params;

    if (!isAddress(address)) {
      return res.status(400).json({
        success: false,
        message: "Invalid address format",
      });
    }

    const normalizedAddress = address.toLowerCase();

    const user = await prisma.userPosition.findUnique({
      where: { userAddress: normalizedAddress },
    });

    if (!user) {
      return res.status(200).json({
        success: true,
        data: {
          address: normalizedAddress,
          totalDeposits: "0",
          totalWithdrawals: "0",
          totalShares: "0",
        },
      });
    }

    return res.status(200).json({
      success: true,
      data: {
        address: user.userAddress,
        totalDeposits: user.totalDeposits.toString(),
        totalWithdrawals: user.totalWithdrawals.toString(),
        totalShares: user.totalShares.toString(),
      },
    });
  } catch (error) {
    console.error("User position error:", error);

    return res.status(500).json({
      success: false,
      message: "Internal server error",
    });
  }
};
