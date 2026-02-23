import express from "express";
import {
  adminLogin,
  pauseVault,
  simulateYield,
  unpauseVault,
  updateCap,
} from "../controllers/admin.controller.js";
import { authenticateJwt } from "../middleware/auth.middleware.js";
import { authorizeRole } from "../middleware/role.middleware.js";

const router = express.Router();

router.post("/login", adminLogin);

router.use(authenticateJwt);
router.use(authorizeRole);

router.post("/pause", pauseVault);
router.post("/unpause", unpauseVault);
router.post("/cap-update", updateCap);
router.post("/yield-update", simulateYield);

export default router;
