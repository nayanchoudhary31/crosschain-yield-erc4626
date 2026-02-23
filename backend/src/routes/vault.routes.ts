import { getVaultStats } from "../controllers/vault.controller.js";
import express from "express";

const router = express.Router();

router.get("/stats", getVaultStats);

export default router;
