"use client";
import Image from "next/image";
import { Button } from "@/components/ui/button";
import { WalletSelector } from "@/components/WalletSelector";
import PixelLogo from '../components/PixelLogo'
import Head from 'next/head'
import WalletConnectDemo from "@/components/WalletConnect";
import ASCIIBackground from '../components/ASCIIBackground'
import ASCIIButton from '../components/ASCIIButton'
import { SingleSigner } from "@/components/transactionFlows/SingleSigner";

import {
  AccountInfo,
  AptosChangeNetworkOutput,
  NetworkInfo,
  WalletInfo,
  isAptosNetwork,
  useWallet,
} from "@aptos-labs/wallet-adapter-react";

export default function Home() {
  const { account, connected, network, wallet, changeNetwork } = useWallet();

  return (
    <div className="relative min-h-screen flex flex-col items-center justify-center bg-black text-yellow-100 overflow-hidden">
      <Head>
        <title>Forge Force</title>
        <link rel="icon" href="/favicon.ico" />
      </Head>

      <ASCIIBackground />

      <main className="z-10 flex-1 flex-col items-center justify-center px-4 sm:px-20 text-center">


        <div className="mb-12 transform hover:scale-105 transition-transform duration-300">
          <PixelLogo />
        </div>


        <div className="flex flex-col sm:flex-row justify-center items-center gap-8">


        <WalletSelector />
        {connected && (
        <>
          <SingleSigner />
        </>
      )}
        </div>
      </main>

      <footer className="z-10 w-full py-8 border-t border-yellow-900 text-center">
        <p className="text-sm">
        @ 2024 ForgeForce, All Rights Reserved
        </p>
      </footer>
    </div>
  );
}
