import {
  useAccount,
  useReadContract,
} from "wagmi";
import { useEffect, useState } from "react";
import { toast } from "react-toastify";
import userRegistryABI from "../src/contracts/userRegistry.json";
import { useSendTransaction, useWallets } from "@privy-io/react-auth";
import { encodeFunctionData } from "viem";

// ============================================================
// 🔍 READ USER STATE — FULL LOGGING
// ============================================================
export function useReadUser(userAddress: `0x${string}` | undefined) {
  const contractAddress = process.env
    .NEXT_PUBLIC_USER_REGISTRY_CONTRACT_ADDRESS as `0x${string}`;

  const { data, isLoading, isError, refetch } = useReadContract({
    address: contractAddress,
    abi: userRegistryABI,
    functionName: "isRegistered",
    args: userAddress ? [userAddress] : undefined, // ✅ pass the address here
    query: {
      enabled: !!userAddress,
    },
  });

  // Log lifecycle changes
  useEffect(() => {
    // if (isError)
    // if (data !== undefined)
  }, [data, isLoading, isError]);

  return { data, isLoading, isError, refetch };
}

// ============================================================
// ⚙️ USER ACTIONS — WRITE + CONFIRMATION FULL LOGGING
// ============================================================
export function useUserActions(userAddress: `0x${string}` | undefined) {
  const { wallets } = useWallets();
  const { sendTransaction } = useSendTransaction();

  const contractAddress = process.env
    .NEXT_PUBLIC_USER_REGISTRY_CONTRACT_ADDRESS as `0x${string}`;

  // Local status tracking
  const [status, setStatus] = useState<
    "idle" | "pending" | "success" | "error"
  >("idle");
  const [txHash, setTxHash] = useState<string | null>(null);
  const [txError, setTxError] = useState<Error | null>(null);

  const registerUser = async () => {
    if (!userAddress) {
      toast.error("Wallet not connected or address missing!");
      return;
    }
    const embedded = wallets?.[0]?.address;
    if (!embedded) {
      toast.error("Embedded wallet not found.");
      return;
    }

    const data = encodeFunctionData({
      abi: userRegistryABI,
      functionName: "register",
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
      toast.success("✅ Gasless user registration transaction sent: " + hash);
    } catch (error: any) {
      console.error("Gasless user registration failed", error);
      setTxError(error);
      setStatus("error");
      toast.error("❌ Gasless user registration failed: " + (error.message || "Unknown error"));
    }
  };

  return {
    registerUser,
    status,
    txHash,
    error: txError,
    isLoading: status === "pending",
    isSuccess: status === "success",
    isError: status === "error",
  };
}
