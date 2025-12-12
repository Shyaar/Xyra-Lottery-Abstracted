// hooks/useBuyTicketWrite.ts
import { useState, useEffect } from "react";
import { toast } from "react-toastify";
import { useAccount } from "wagmi";
import { useSendTransaction, useWallets } from "@privy-io/react-auth";
import { encodeFunctionData } from "viem";
import lotteryManagerABI from "../src/contracts/LotteryManager.json";
import { useUserTickets } from "./useReadLottery";

const contractAddress = process.env
  .NEXT_PUBLIC_LOTTERY_MANAGER_CONTRACT_ADDRESS as `0x${string}`;

export function useBuyTicketWrite() {
  const { address: caller } = useAccount();
  const { wallets } = useWallets();
  const { sendTransaction } = useSendTransaction();
  const { refetch: refetchUserTickets } = useUserTickets(caller);

  // Local status tracking
  const [status, setStatus] = useState<
    "idle" | "pending" | "success" | "error"
  >("idle");
  const [txHash, setTxHash] = useState<string | null>(null);
  const [txError, setTxError] = useState<Error | null>(null);

  const buyTicket = async (amount: bigint) => {
    if (!caller) {
      // toast.error("Please connect your wallet to buy a ticket.");
      return;
    }
    const embedded = wallets?.[0]?.address;
    if (!embedded) {
      toast.error("Embedded wallet not found.");
      return;
    }

    const data = encodeFunctionData({
      abi: lotteryManagerABI,
      functionName: "buyTicket",
      args: [amount],
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
      toast.success("✅ Gasless ticket purchase transaction sent: " + hash);
      refetchUserTickets();
    } catch (error: any) {
      console.error("Gasless buy ticket failed", error);
      setTxError(error);
      setStatus("error");
      toast.error("❌ Gasless buy ticket failed: " + (error.message || "Unknown error"));
    }
  };

  return {
    buyTicket,
    status,
    txHash,
    error: txError,
    isLoading: status === "pending",
    isSuccess: status === "success",
    isError: status === "error",
  };
}
