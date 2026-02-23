-- CreateEnum
CREATE TYPE "EventType" AS ENUM ('DEPOSIT', 'WITHDRAW');

-- CreateTable
CREATE TABLE "events" (
    "id" SERIAL NOT NULL,
    "tx_hash" VARCHAR(66) NOT NULL,
    "log_index" INTEGER NOT NULL,
    "block_number" BIGINT NOT NULL,
    "block_hash" VARCHAR(66),
    "user_address" VARCHAR(42) NOT NULL,
    "amount" DECIMAL(65,30) NOT NULL,
    "shares" DECIMAL(65,30) NOT NULL,
    "event_type" "EventType" NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sync_state" (
    "id" INTEGER NOT NULL DEFAULT 1,
    "last_processed_block" BIGINT NOT NULL,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "sync_state_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vault_stats" (
    "id" INTEGER NOT NULL DEFAULT 1,
    "total_deposits" DECIMAL(65,30) NOT NULL DEFAULT 0,
    "total_shares" DECIMAL(65,30) NOT NULL DEFAULT 0,
    "user_count" INTEGER NOT NULL DEFAULT 0,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "vault_stats_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_positions" (
    "user_address" VARCHAR(42) NOT NULL,
    "total_deposits" DECIMAL(65,30) NOT NULL DEFAULT 0,
    "total_shares" DECIMAL(65,30) NOT NULL DEFAULT 0,
    "last_updated" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "user_positions_pkey" PRIMARY KEY ("user_address")
);

-- CreateIndex
CREATE INDEX "events_user_address_idx" ON "events"("user_address");

-- CreateIndex
CREATE INDEX "events_block_number_idx" ON "events"("block_number");

-- CreateIndex
CREATE UNIQUE INDEX "events_tx_hash_log_index_key" ON "events"("tx_hash", "log_index");
