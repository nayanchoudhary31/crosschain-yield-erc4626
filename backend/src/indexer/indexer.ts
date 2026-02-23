import prisma from "../db/db.js";
import { provider } from "./contract.js";
import { processBlock } from "./processor.js";

const CONFIRMATIONS = 3;
const POLL_INTERVAL = 3000;

export const startIndexer = async () => {
  console.log("Indexer started...");

  while (true) {
    try {
      const latestBlock = await provider.getBlockNumber();
      const safeBlock = latestBlock - CONFIRMATIONS;

      const syncState = await prisma.syncState.findUnique({
        where: { id: 1 },
      });

      const lastSafeBlock = Number(syncState?.lastSafeBlock ?? 0);

      if (safeBlock <= lastSafeBlock) {
        await sleep(POLL_INTERVAL);
        continue;
      }

      for (let block = lastSafeBlock + 1; block <= safeBlock; block++) {
        await processBlock(block);
      }

      await prisma.syncState.upsert({
        where: { id: 1 },
        create: {
          id: 1,
          lastProcessedBlock: BigInt(safeBlock),
          lastSafeBlock: BigInt(safeBlock),
        },
        update: {
          lastProcessedBlock: BigInt(safeBlock),
          lastSafeBlock: BigInt(safeBlock),
        },
      });
    } catch (err) {
      console.error("Indexer error:", err);
      await sleep(5000);
    }
  }
};

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));
