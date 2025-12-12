'use client';

import React, { useEffect } from 'react';
import { usePrivy } from '@privy-io/react-auth';
import { useRouter } from 'next/navigation';

export function SignUpButton() {
  const router = useRouter()
  const { login, logout, ready, authenticated } = usePrivy();

 useEffect(()=>{
   if(ready && authenticated){
    router.push("/home-page")
  }
  // else{
  //   router.push("/")
  // }
 },[ready,authenticated])

  return (
    <button
      onClick={authenticated ? logout : login}
      disabled={!ready}
      className="px-6 py-3 bg-yellow-400 text-black rounded font-semibold text-sm hover:bg-yellow-500 disabled:bg-yellow-400/10 transition-all transform hover:scale-105 uppercase tracking-wide"
    >
      {authenticated ? "Logout" : "Launch App"}
    </button>
  );
}