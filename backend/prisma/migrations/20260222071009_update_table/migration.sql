/*
  Warnings:

  - You are about to alter the column `amount` on the `events` table. The data in that column could be lost. The data in that column will be cast from `Decimal(65,30)` to `Decimal(78,0)`.
  - You are about to alter the column `shares` on the `events` table. The data in that column could be lost. The data in that column will be cast from `Decimal(65,30)` to `Decimal(78,0)`.
  - You are about to alter the column `total_deposits` on the `user_positions` table. The data in that column could be lost. The data in that column will be cast from `Decimal(65,30)` to `Decimal(78,0)`.
  - You are about to alter the column `total_shares` on the `user_positions` table. The data in that column could be lost. The data in that column will be cast from `Decimal(65,30)` to `Decimal(78,0)`.
  - You are about to alter the column `total_deposits` on the `vault_stats` table. The data in that column could be lost. The data in that column will be cast from `Decimal(65,30)` to `Decimal(78,0)`.
  - You are about to alter the column `total_shares` on the `vault_stats` table. The data in that column could be lost. The data in that column will be cast from `Decimal(65,30)` to `Decimal(78,0)`.
  - Added the required column `chain_id` to the `events` table without a default value. This is not possible if the table is not empty.
  - Added the required column `contract_address` to the `events` table without a default value. This is not possible if the table is not empty.
  - Added the required column `last_safe_block` to the `sync_state` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE "events" ADD COLUMN     "chain_id" INTEGER NOT NULL,
ADD COLUMN     "confirmed" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "contract_address" VARCHAR(42) NOT NULL,
ADD COLUMN     "removed" BOOLEAN NOT NULL DEFAULT false,
ALTER COLUMN "amount" SET DATA TYPE DECIMAL(78,0),
ALTER COLUMN "shares" SET DATA TYPE DECIMAL(78,0);

-- AlterTable
ALTER TABLE "sync_state" ADD COLUMN     "last_safe_block" BIGINT NOT NULL;

-- AlterTable
ALTER TABLE "user_positions" ADD COLUMN     "total_withdrawals" DECIMAL(78,0) NOT NULL DEFAULT 0,
ALTER COLUMN "total_deposits" SET DATA TYPE DECIMAL(78,0),
ALTER COLUMN "total_shares" SET DATA TYPE DECIMAL(78,0);

-- AlterTable
ALTER TABLE "vault_stats" ADD COLUMN     "total_withdrawals" DECIMAL(78,0) NOT NULL DEFAULT 0,
ALTER COLUMN "total_deposits" SET DATA TYPE DECIMAL(78,0),
ALTER COLUMN "total_shares" SET DATA TYPE DECIMAL(78,0);

-- CreateIndex
CREATE INDEX "events_confirmed_idx" ON "events"("confirmed");
