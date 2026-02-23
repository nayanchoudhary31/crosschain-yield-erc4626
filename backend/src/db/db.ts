import { PrismaClient } from "@prisma/client";
import dotenv from "dotenv";
dotenv.config();

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined;
};

export const prisma = globalForPrisma.prisma ?? new PrismaClient();

if (process.env.NODE_ENV !== "production") {
  globalForPrisma.prisma = prisma;
}

// Graceful shutdown
const shutdown = async () => {
  try {
    await prisma.$disconnect();
  } catch (_) {}
};
process.on("beforeExit", shutdown);
process.on("SIGINT", async () => {
  await shutdown();
  process.exit(0);
});
process.on("SIGTERM", async () => {
  await shutdown();
  process.exit(0);
});

export default prisma;
