# ForgeForce
## Overview
A fully on-chain card game that introduces a unique cooperative battle mechanic. Instead of players directly competing against each other, they collectively fight a public monster. This monster represents a prize pool, which is funded by various sources including card pack sales and trading fees from a dedicated NFT marketplace.

## Key Features
- **Customizable Attack Styles** : Players can choose their desired attack style. Based on their chosen style, the return and risk can vary.
- **Card NFTs**: Unique, collectible cards with varying attributes and features that players can trade or use in battles.
- **Dynamic Prize Pool**: Funded by card pack sales and marketplace transaction fees, ensuring continuous growth. 
- **Fully On-Chain**: All game mechanics, including card attributes, damage calculations, and prize distributions, are managed by smart contracts, ensuring transparency and fairness.

## Models Diagram

> TODO

## Planning
This project is started for attending **Battle of Olympus Program**, hosted by **Movement**. While we are ambitious about completing our vision for the project, our top priority during the program is to build a solid foundation for the future.

Hence, in **Battle of Olympus Program**, we will mainly focus on building the fundamental features, including:

- Designing an appropriate game economy, which is crucial for our project's future.
- Designing the core card utilities, carefully balanced with the overall game structure.
- Implementing the basic functions of the game, such as basic attack actions and basic monster generation events.
- Implementing a basic frontend website to demonstrate the entire process.

## Basic Demo

Check out the demo site: [Forge Force Demo](https://forge-force.vercel.app/)

### Summary

Currently, the app only supports the Aptos testnet due to limitations with the randomness package on the Movement Suzuke testnet. The contract uses the native gas token for transactions (APT on Aptos Testnet and MOVE on Suzuke). In the future, I plan to introduce a new token for app transactions and a Card NFT.

The dApp allows users to select two parameters:

1.  **Energy** - the amount of tokens you wish to use. (Using Gas token Currently)

2.  **Attack Aggressiveness** - a higher setting can yield greater returns but also increases the chance of failure.

### Steps to Use the DApp:

**Step 1**

On the landing page, connect your wallet using the Aptos Testnet. **(Will be avaible on Movement Suzuke testnet once the randomness issue is resolved.)**

**Step 2**

Enter a token amount in the textbox. Be mindful of your balance, as the contract will reject transactions with insufficient funds.

**Step 3**

Adjust the desired aggressiveness rate. The dApp will provide detailed info based on your chosen rate.

**Step 4**

Click "Attack" and approve the transaction.

**Step 5**

-  If successful, you can view the transaction in the explorer by clicking the link in the bottom-right corner.

-  If it fails, try lowering the token amount and attempting again.
