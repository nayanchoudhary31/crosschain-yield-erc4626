import type { Request, Response } from "express";
import prisma from "../db/db.js";
import { isAddress } from "ethers";

export const getTransactions = async (req: Request, res: Response) => {
  try {
    const { address } = req.params;
    const { page = "1", limit = "20" } = req.query;

    // ✅ Validate address
    if (!isAddress(address)) {
      return res.status(400).json({
        success: false,
        message: "Invalid address format",
      });
    }

    const normalizedAddress = address.toLowerCase();

    const pageNumber = Math.max(Number(page), 1);
    const limitNumber = Math.min(Math.max(Number(limit), 1), 100); // max 100

    const skip = (pageNumber - 1) * limitNumber;

    // Only confirmed events
    const [transactions, total] = await Promise.all([
      prisma.event.findMany({
        where: {
          userAddress: normalizedAddress,
          confirmed: true,
          removed: false,
        },
        orderBy: {
          blockNumber: "desc",
        },
        skip,
        take: limitNumber,
      }),

      prisma.event.count({
        where: {
          userAddress: normalizedAddress,
          confirmed: true,
          removed: false,
        },
      }),
    ]);

    return res.status(200).json({
      success: true,
      data: {
        page: pageNumber,
        limit: limitNumber,
        total,
        transactions: transactions.map((tx) => ({
          txHash: tx.txHash,
          blockNumber: tx.blockNumber.toString(),
          eventType: tx.eventType,
          amount: tx.amount.toString(),
          shares: tx.shares.toString(),
        })),
      },
    });
  } catch (error) {
    console.error("Transactions error:", error);

    return res.status(500).json({
      success: false,
      message: "Internal server error",
    });
  }
};
