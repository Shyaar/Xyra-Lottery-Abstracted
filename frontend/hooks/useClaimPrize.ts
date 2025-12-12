// hooks/useClaimPrize.ts
import { useState, useEffect } from "react";
import { toast } from "react-toastify";
import { useAccount } from "wagmi";
import { useSendTransaction, useWallets } from "@privy-io/react-auth";
import { encodeFunctionData } from "viem";
import lotteryManagerABI from "../src/contracts/LotteryManager.json";

const contractAddress = process.env
  .NEXT_PUBLIC_LOTTERY_MANAGER_CONTRACT_ADDRESS as `0x${string}`;

export function useClaimPrize() {
  const { address: caller } = useAccount();
  const { wallets } = useWallets();
  const { sendTransaction } = useSendTransaction();

  // Local status tracking
  const [status, setStatus] = useState<
    "idle" | "pending" | "success" | "error"
  >("idle");
  const [txHash, setTxHash] = useState<string | null>(null);
  const [txError, setTxError] = useState<Error | null>(null);

  const claimPrize = async () => {
    if (!caller) {
      // toast.error("Please connect your wallet to claim prize.");
      return;
    }
    const embedded = wallets?.[0]?.address;
    if (!embedded) {
      toast.error("Embedded wallet not found.");
      return;
    }

    const data = encodeFunctionData({
      abi: lotteryManagerABI,
      functionName: "claimPrize",
      args: [],
    });

    setStatus("pending");
    setTxError(null);
    setTxHash(null);

    try {
      const result = await sendTransaction(
        {
          to: contractAddress,
          data,
          value: 0n,
        },
        {
          sponsor: true,
          address: embedded,
        }
      );
      const hash = (result as any).hash as string;
      setTxHash(hash);
      toast.info("Transaction sent, awaiting confirmation…");
      setStatus("success");
      toast.success("✅ Gasless prize claim transaction sent: " + hash);
    } catch (error: any) {
      console.error("Gasless claim prize failed", error);
      setTxError(error);
      setStatus("error");
      toast.error("❌ Gasless claim prize failed: " + (error.message || "Unknown error"));
    }
  };

  return {
    claimPrize,
    status,
    txHash,
    error: txError,
    isLoading: status === "pending",
    isSuccess: status === "success",
    isError: status === "error",
  };
}