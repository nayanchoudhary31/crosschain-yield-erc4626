import { getTransactions } from "../controllers/transactions.controller.js";
import express from "express";

const router = express.Router();

router.get("/:address", getTransactions);

export default router;
