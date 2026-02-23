import { getUserPosition } from "../controllers/users.controller.js";
import express from "express";

const router = express.Router();

router.get("/:address/position", getUserPosition);

export default router;
