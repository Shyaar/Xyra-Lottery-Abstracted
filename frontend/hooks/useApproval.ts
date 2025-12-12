import { useState, useEffect } from "react";
import { toast } from "react-toastify";
import { useAccount } from "wagmi";
import { useSendTransaction, useWallets } from "@privy-io/react-auth";
import { encodeFunctionData, erc20Abi } from "viem";

const USDC_ADDRESS = process.env.NEXT_PUBLIC_USDC_TOKEN_ADDRESS as `0x${string}`;
const LOTTERY_MANAGER_ADDRESS = (process.env.NEXT_PUBLIC_LOTTERY_MANAGER_CONTRACT_ADDRESS as `0x${string}`) || "";

export function useApproveUSDCGasless() {
  const { address: caller } = useAccount();
  const { wallets } = useWallets();
  const { sendTransaction } = useSendTransaction();

  // Local status tracking
  const [status, setStatus] = useState<
    "idle" | "pending" | "success" | "error"
  >("idle");
  const [txHash, setTxHash] = useState<string | null>(null);
  const [txError, setTxError] = useState<Error | null>(null);

  const approve = async (amount: bigint) => {
    if (!caller) {
      // toast.error("Please connect your wallet first.");
      return;
    }
    const embedded = wallets?.[0]?.address;
    if (!embedded) {
      toast.error("Embedded wallet not found.");
      return;
    }

    const data = encodeFunctionData({
      abi: erc20Abi,
      functionName: "approve",
      args: [LOTTERY_MANAGER_ADDRESS, amount],
    });

    setStatus("pending");
    setTxError(null);
    setTxHash(null);

    try {
      const result = await sendTransaction(
        {
          to: USDC_ADDRESS,
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
      // Optionally: here you could poll for receipt or use a library to await confirmation
      setStatus("success");
      toast.success("✅ Gasless approval transaction sent: " + hash);
    } catch (error: any) {
      console.error("Gasless approve failed", error);
      setTxError(error);
      setStatus("error");
      toast.error("❌ Gasless approve failed: " + (error.message || "Unknown error"));
    }
  };

  return {
    approve,
    status,
    txHash,
    error: txError,
    isLoading: status === "pending",
    isSuccess: status === "success",
    isError: status === "error",
  };
}
