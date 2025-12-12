// hooks/useLotteryWrite.ts
import { useState } from "react";
import { toast } from "react-toastify";
import { useSendTransaction, useWallets } from "@privy-io/react-auth";
import { encodeFunctionData } from "viem";
import lotteryManagerABI from "../src/contracts/LotteryManager.json";
import tokenVaultABI from "../src/contracts/TokenVault.json";

const lotteryManagerAddress = process.env
  .NEXT_PUBLIC_LOTTERY_MANAGER_CONTRACT_ADDRESS as `0x${string}`;
const tokenVaultAddress = process.env
  .NEXT_PUBLIC_TOKEN_VAULT_CONTRACT_ADDRESS as `0x${string}`;

export function useLotteryWrite() {
  const { wallets } = useWallets();
  const { sendTransaction } = useSendTransaction();

  const [functionName, setFunctionName] = useState<string | null>(null);
  const [isWithdrawSuccessful, setIsWithdrawSuccessful] = useState(false);
  const [status, setStatus] = useState<"idle" | "pending" | "success" | "error">(
    "idle"
  );
  const [txHash, setTxHash] = useState<string | null>(null);
  const [txError, setTxError] = useState<Error | null>(null);

  const resetWithdrawSuccess = () => {
    console.log("DEBUG: resetWithdrawSuccess() called");
    setIsWithdrawSuccessful(false);
  };

  const executeTransaction = async (
    toAddress: `0x${string}`,
    abi: any,
    fnName: string,
    args: any[]
  ) => {
    console.log("DEBUG: executeTransaction called:", {
      toAddress,
      fnName,
      args,
      wallets,
    });

    const embedded = wallets?.[0]?.address;

    if (!embedded) {
      console.log("DEBUG: No embedded wallet found");
      toast.error("Embedded wallet not found.");
      throw new Error("Embedded wallet not found.");
    }

    const data = encodeFunctionData({
      abi,
      functionName: fnName,
      args,
    });

    console.log("DEBUG: Encoded function data:", data);

    setStatus("pending");
    setTxError(null);
    setTxHash(null);

    try {
      console.log("DEBUG: Executing sendTransaction…");

      const result = await sendTransaction(
        {
          to: toAddress,
          data,
          value: 0n,
        },
        {
          sponsor: true,
          address: embedded,
        }
      );

      console.log("DEBUG: sendTransaction result:", result);

      const hash = (result as any).hash;
      setTxHash(hash);

      console.log("DEBUG: Transaction sent:", hash);

      toast.info("Transaction sent, awaiting confirmation…");
      toast.success("✅ Gasless transaction submitted!");

      setStatus("success");

      if (fnName === "emergencyWithdrawAllFromStrategy") {
        console.log("DEBUG: emergencyWithdrawAllFromStrategy success flag set");
        setIsWithdrawSuccessful(true);
      }
      return result;
    } catch (error: any) {
      console.error("DEBUG: Transaction failed:", error);
      setTxError(error);
      setStatus("error");
      toast.error("❌ Transaction failed: " + (error.message || "Unknown error"));
      throw error;
    }
  };

  // === Action Helpers ===

  const performStart = async () => {
    console.log("DEBUG: performStart called");
    setFunctionName("performStart");
    return await executeTransaction(lotteryManagerAddress, lotteryManagerABI, "performStart", []);
  };

  const performClose = async () => {
    console.log("DEBUG: performClose called");
    setFunctionName("performClose");
    return await executeTransaction(lotteryManagerAddress, lotteryManagerABI, "performClose", []);
  };

  const earnAndHarvest = async () => {
    console.log("DEBUG: earnAndHarvest called");
    setFunctionName("earnAndHarvest");
    return await executeTransaction(tokenVaultAddress, tokenVaultABI, "earnAndHarvest", []);
  };

  const emergencyWithdrawFromStrategy = async () => {
    console.log("DEBUG: emergencyWithdraw clicked");
    setFunctionName("emergencyWithdrawAllFromStrategy");
    return await executeTransaction(
      tokenVaultAddress,
      tokenVaultABI,
      "emergencyWithdrawAllFromStrategy",
      []
    );
  };

  const resetVaultFlags = async () => {
    console.log("DEBUG: resetFlags called");
    setFunctionName("resetFlags");
    return await executeTransaction(tokenVaultAddress, tokenVaultABI, "resetFlags", []);
  };

  return {
    performStart,
    performClose,
    earnAndHarvest,
    emergencyWithdrawFromStrategy,
    resetVaultFlags,

    status,
    txHash,
    error: txError,

    isLoading: status === "pending",
    isSuccess: status === "success",
    isError: status === "error",

    isWithdrawSuccessful,
    resetWithdrawSuccess,

    functionName,
  };
}
