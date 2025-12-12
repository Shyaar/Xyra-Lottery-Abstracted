import { useState, useEffect } from "react";
import { toast } from "react-toastify";
import { useAccount } from "wagmi";
import { useSendTransaction, useWallets } from "@privy-io/react-auth";
import { encodeFunctionData } from "viem";
import lotteryManagerABI from "../src/contracts/LotteryManager.json";
import { useRoundActive, useRoundEndTimestamp } from "./useReadLottery";

export function useStartRound() {
  const { address: caller } = useAccount();
  const { wallets } = useWallets();
  const { sendTransaction } = useSendTransaction();

  const contractAddress = process.env
    .NEXT_PUBLIC_LOTTERY_MANAGER_CONTRACT_ADDRESS as `0x${string}`;

  const { refetch: refetchRoundActive } = useRoundActive();
  const { refetch: refetchRoundEndTimestamp } = useRoundEndTimestamp();

  // Local status tracking
  const [status, setStatus] = useState<
    "idle" | "pending" | "success" | "error"
  >("idle");
  const [txHash, setTxHash] = useState<string | null>(null);
  const [txError, setTxError] = useState<Error | null>(null);

  const startRound = async (durationSeconds: number) => {
    if (!caller) {
      // toast.error("Please connect your wallet!");
      return;
    }
    const embedded = wallets?.[0]?.address;
    if (!embedded) {
      toast.error("Embedded wallet not found.");
      return;
    }

    const data = encodeFunctionData({
      abi: lotteryManagerABI,
      functionName: "startRound",
      args: [durationSeconds],
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
      toast.success("✅ Gasless round start transaction sent: " + hash);
      refetchRoundActive();
      refetchRoundEndTimestamp();
    } catch (error: any) {
      console.error("Gasless start round failed", error);
      setTxError(error);
      setStatus("error");
      toast.error("❌ Gasless start round failed: " + (error.message || "Unknown error"));
    }
  };

  return {
    startRound,
    status,
    txHash,
    error: txError,
    isLoading: status === "pending",
    isSuccess: status === "success",
    isError: status === "error",
  };
}
