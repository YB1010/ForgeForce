import { Aptos, AptosConfig, Network } from "@aptos-labs/ts-sdk";
import { NetworkInfo } from "@aptos-labs/wallet-adapter-core";

export const aptosClient = (network?: NetworkInfo | null) => {
  console.log(network);
  if (network?.name === Network.DEVNET) {
    return DEVNET_CLIENT;
  } else if (network?.name === Network.TESTNET) {
    return TESTNET_CLIENT;
  } else if (network?.name === Network.MAINNET) {
    throw new Error("Please use devnet or testnet for testing");
  } else if (network?.name === Network.CUSTOM && network?.url === 'https://aptos.testnet.suzuka.movementlabs.xyz/v1') {
    const CUSTOM_CONFIG = new AptosConfig({ 
      network: Network.CUSTOM,
      fullnode: 'https://aptos.testnet.suzuka.movementlabs.xyz/v1',
      faucet: 'https://faucet.testnet.suzuka.movementlabs.xyz',
    });
    return new Aptos(CUSTOM_CONFIG);
  } else if (network?.name === Network.CUSTOM && network?.url === ('https://aptos.devnet.suzuka.movementlabs.xyz/v1' || 'https://devnet.suzuka.movementnetwork.xyz/v1' ) ) {
    const CUSTOM_CONFIG = new AptosConfig({ 
      network: Network.CUSTOM,
      fullnode: 'https://aptos.devnet.suzuka.movementlabs.xyz/v1',
      faucet: 'https://faucet.devnet.suzuka.movementnetwork.xyz',
    });
    return new Aptos(CUSTOM_CONFIG);
  } else{
    throw new Error("Unsupported network");
  }
};

// Devnet client
export const DEVNET_CONFIG = new AptosConfig({
  network: Network.DEVNET,
});
export const DEVNET_CLIENT = new Aptos(DEVNET_CONFIG);

// Testnet client
export const TESTNET_CONFIG = new AptosConfig({ network: Network.TESTNET });
export const TESTNET_CLIENT = new Aptos(TESTNET_CONFIG);

export const isSendableNetwork = (
  connected: boolean,
  networkName?: string,
): boolean => {
  return connected && !isMainnet(connected, networkName);
};

export const isMainnet = (
  connected: boolean,
  networkName?: string,
): boolean => {
  return connected && networkName === Network.MAINNET;
};
