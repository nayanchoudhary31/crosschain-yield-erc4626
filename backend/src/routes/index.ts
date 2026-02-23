import { Router } from "express";
import vaultRoutes from "./vault.routes.js";
import userRoutes from "./users.routes.js";
import transactionsRoutes from "./transactions.routes.js";
import adminRoutes from "./admin.routes.js";

const router = Router();

router.use("/vault", vaultRoutes);
router.use("/user", userRoutes);
router.use("/transactions", transactionsRoutes);
router.use("/admin", adminRoutes);
export default router;
 