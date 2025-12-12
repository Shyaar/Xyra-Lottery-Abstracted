// ============================================================
// 🏦 useVault.ts — Full Logging + Refactored to Your New Style
// ============================================================

import {
  useBalance,
} from "wagmi";
import { useEffect } from "react";
import { toast } from "react-toastify";

// ============================================================
// 🔍 READ: VAULT BALANCE (USDC)
// ============================================================
export function useVaultBalance() {
  const vaultAddress = process.env
    .NEXT_PUBLIC_TOKEN_VAULT_CONTRACT_ADDRESS as `0x${string}`;
  const usdcAddress = process.env
    .NEXT_PUBLIC_USDC_TOKEN_ADDRESS as `0x${string}`;

  const { data, isLoading, isError, refetch } = useBalance({
    address: vaultAddress,
    token: usdcAddress,
    query: {
      enabled: !!vaultAddress && !!usdcAddress,
    },
  });

  useEffect(() => {
    if (isLoading) {
      console.log("Fetching vault balance...");
    }
    if (isError) {
      console.error("Error fetching vault balance.");
      toast.error("Error fetching vault balance.");
    }
    if (data) {
      console.log("Vault balance:", {
        value: data.value,
        formatted: data.formatted,
      });
    }
  }, [data, isLoading, isError]);

  return { balance: data, isLoading, isError, refetch };
}


