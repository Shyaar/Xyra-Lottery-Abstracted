import type { PrivyClientConfig } from '@privy-io/react-auth';
import { baseSepolia } from 'wagmi/chains';

export const privyConfig: PrivyClientConfig = {
  embeddedWallets: {
    ethereum: {
      createOnLogin: "users-without-wallets",  
    },
    showWalletUIs: true,                        
  },
  loginMethods: ['google', 'email', 'github', 'wallet'],
  appearance: {
    showWalletLoginFirst: false,
    theme: 'light',
    accentColor: '#676FFF',
    logo: '/logo-xyra.svg',
  },
  supportedChains: [baseSepolia],
};
