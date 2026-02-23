import prisma from "../db/db.js";
import { vault, provider } from "./contract.js";
import { ethers } from "ethers";
import { Prisma } from "@prisma/client";

export const processBlock = async (blockNumber: number) => {
  console.log("Processing block:", blockNumber);

  // ✅ Use event name string instead of filters (avoids undefined typing issue)
  const depositLogs = await vault.queryFilter(
    "Deposit",
    blockNumber,
    blockNumber,
  );

  const withdrawLogs = await vault.queryFilter(
    "Withdraw",
    blockNumber,
    blockNumber,
  );

  const logs = [...depositLogs, ...withdrawLogs];

  if (logs.length === 0) return;

  const block = await provider.getBlock(blockNumber);
  if (!block) return;

  await prisma.$transaction(async (tx) => {
    for (const log of logs) {
      await handleEvent(tx, log, block);
    }
  });
};

const handleEvent = async (
  tx: Prisma.TransactionClient,
  log: ethers.Log,
  block: ethers.Block,
) => {
  const parsed = vault.interface.parseLog(log);

  // ✅ Strict null safety
  if (!parsed) return;

  const isDeposit = parsed.name === "Deposit";

  const user = parsed.args.owner as string;
  const assets = parsed.args.assets.toString();
  const shares = parsed.args.shares.toString();

  // =============================
  // 1️⃣ Insert Event (Idempotent)
  // =============================
  try {
    await tx.event.create({
      data: {
        chainId: 1,
        contractAddress: log.address,
        txHash: log.transactionHash,
        logIndex: log.index,
        blockNumber: BigInt(log.blockNumber),
        blockHash: block.hash!,
        userAddress: user,
        amount: assets,
        shares: shares,
        eventType: isDeposit ? "DEPOSIT" : "WITHDRAW",
        confirmed: true,
      },
    });
  } catch (err: any) {
    if (err.code === "P2002") {
      // Duplicate event → ignore
      return;
    }
    throw err;
  }

  // =============================
  // 2️⃣ Update Vault Stats
  // =============================
  const vaultUpdate: Prisma.VaultStatsUpdateInput = {
    totalShares: isDeposit ? { increment: shares } : { decrement: shares },
  };

  if (isDeposit) {
    vaultUpdate.totalDeposits = { increment: assets };
  } else {
    vaultUpdate.totalWithdrawals = { increment: assets };
  }

  await tx.vaultStats.upsert({
    where: { id: 1 },
    create: {
      id: 1,
      totalDeposits: isDeposit ? assets : "0",
      totalWithdrawals: isDeposit ? "0" : assets,
      totalShares: isDeposit ? shares : `-${shares}`,
      userCount: 1,
    },
    update: vaultUpdate,
  });

  // =============================
  // 3️⃣ Update User Position
  // =============================
  const userUpdate: Prisma.UserPositionUpdateInput = {
    totalShares: isDeposit ? { increment: shares } : { decrement: shares },
  };

  if (isDeposit) {
    userUpdate.totalDeposits = { increment: assets };
  } else {
    userUpdate.totalWithdrawals = { increment: assets };
  }

  await tx.userPosition.upsert({
    where: { userAddress: user },
    create: {
      userAddress: user,
      totalDeposits: isDeposit ? assets : "0",
      totalWithdrawals: isDeposit ? "0" : assets,
      totalShares: isDeposit ? shares : `-${shares}`,
    },
    update: userUpdate,
  });
};
