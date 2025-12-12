// hooks/useClaimPrincipal.ts
import { useState, useEffect } from "react";
import { toast } from "react-toastify";
import { useAccount } from "wagmi";
import { useSendTransaction, useWallets } from "@privy-io/react-auth";
import { encodeFunctionData } from "viem";
import lotteryManagerABI from "../src/contracts/LotteryManager.json";

const contractAddress = process.env
  .NEXT_PUBLIC_LOTTERY_MANAGER_CONTRACT_ADDRESS as `0x${string}`;

export function useClaimPrincipal() {
  const { address: caller } = useAccount();
  const { wallets } = useWallets();
  const { sendTransaction } = useSendTransaction();

  // Local status tracking
  const [status, setStatus] = useState<
    "idle" | "pending" | "success" | "error"
  >("idle");
  const [txHash, setTxHash] = useState<string | null>(null);
  const [txError, setTxError] = useState<Error | null>(null);

  const claimPrincipal = async () => {
    if (!caller) {
      // toast.error("Please connect your wallet to claim principal.");
      return;
    }
    const embedded = wallets?.[0]?.address;
    if (!embedded) {
      toast.error("Embedded wallet not found.");
      return;
    }

    const data = encodeFunctionData({
      abi: lotteryManagerABI,
      functionName: "claimPrincipal",
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
      toast.success("✅ Gasless principal claim transaction sent: " + hash);
    } catch (error: any) {
      console.error("Gasless claim principal failed", error);
      setTxError(error);
      setStatus("error");
      toast.error("❌ Gasless claim principal failed: " + (error.message || "Unknown error"));
    }
  };

  return {
    claimPrincipal,
    status,
    txHash,
    error: txError,
    isLoading: status === "pending",
    isSuccess: status === "success",
    isError: status === "error",
  };
}