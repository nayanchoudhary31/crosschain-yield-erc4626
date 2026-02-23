import { ethers } from "ethers";
import dotenv from "dotenv";
import vaultArtifact from "../../../out/YieldVault.sol/YieldVault.json" with { type: "json" };
dotenv.config();

const RPC_URL = process.env.RPC_URL!;
const VAULT_ADDRESS = process.env.VAULT_ADDRESS!;
const PRIVATE_KEY = process.env.ADMIN_PRIVATE_KEY!;

const vaultABI = vaultArtifact.abi;

export const provider = new ethers.JsonRpcProvider(RPC_URL);

const signer = new ethers.Wallet(PRIVATE_KEY, provider);

export const vault = new ethers.Contract(VAULT_ADDRESS, vaultABI, signer);
