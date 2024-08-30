import { isSendableNetwork, aptosClient } from "@/utils";
import { parseTypeTag, AccountAddress, U64 } from "@aptos-labs/ts-sdk";
import { InputTransactionData } from "@aptos-labs/wallet-adapter-core";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { Button } from "../ui/button";
import { Card, CardHeader, CardTitle, CardContent } from "../ui/card";
import { useToast } from "../ui/use-toast";
import { TransactionHash } from "../TransactionHash";
import ASCIIButton from "../ASCIIButton";
import { SetStateAction, useState, useEffect, useCallback, useMemo } from 'react';
// @ts-ignore
import Slider from 'rc-slider';
import 'rc-slider/assets/index.css';
import axios from 'axios'; // Make sure to install axios: npm install axios
import AttackHistory from "../AttackHistory";
import MonsterStatus from "../MonsterStatus";
import Image from 'next/image';
import { Monster } from "../MonsterStatus"; // Adjust the path accordingly

const API_URL = 'https://api.helloapple.xyz';

interface SingleSignerProps {}

export function SingleSigner({}: SingleSignerProps) {
  const [lastTransactionTime, setLastTransactionTime] = useState<number | null>(null);
  const { toast } = useToast();
  const {
    connected,
    account,
    network,
    signAndSubmitTransaction,
    signMessageAndVerify,
    signMessage,
    signTransaction,
  } = useWallet();
  let sendable = isSendableNetwork(connected, network?.name);
  const [input1, setInput1] = useState('');
  const [input2, setInput2] = useState(0); 
  const returnrate = (input2: number) => {
    return 100 / (100 - input2) * 100
  }
  const [playerBalance, setPlayerBalance] = useState<string>('');
  const [monster, setMonster] = useState<Monster | null>(null);

  const fetchPlayerBalance = useCallback(async () => {
    if (!account) return;
    try {
      const balance = await aptosClient(network).getAccountResource({
        accountAddress: account.address,
        resourceType: "0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>"
      });
      setPlayerBalance(balance.coin.value);

    } catch (error) {
      console.error("Error fetching player balance:", error);
    }
  }, [account, network]);
  
  useEffect(() => {
    if (connected && account) {
      fetchPlayerBalance();
    }
  }, [connected, account, fetchPlayerBalance]);
  
  const calculatePotentialReturn = (monsterDefense: number, monsterHp: number , isDamage: boolean) => {
    if (!input1 || input2 === undefined) {
      console.log('Returning 0 due to missing inputs');
      return 0;
    }

    const stakeAmount = parseFloat(input1);
    const aggressive = input2;

    // Calculate the return multiplier
    const returnMultiplier = 100 / (100 - aggressive) - 1;

    // Calculate the effective amount
    const effectiveAmount = stakeAmount * returnMultiplier;

    // Calculate the damage amount
    const damageAmount = effectiveAmount * (100 - monsterDefense) / 100;

    console.log('Calculated damageAmount:', damageAmount);

    // The result is the minimum of the calculated damage and the monster's HP
    const result = Math.min(damageAmount, monsterHp);

    if (isDamage) {
      return result * 100000000;
    } else {
      return result + stakeAmount;
    }
  };

  const onSignAndSubmitTransaction = async (functionArguments: any[]) => {
    if (!account) return;
    const transaction: InputTransactionData = {
      data: {
        function: "0x9b27f03f0b1258f467255e61dcbca5e8d2d0c41a66770b59c1f6cd8d5eea12c6::forge_force_dev_v8::forge_attack_with_aggressive",
        functionArguments: [Math.round(parseFloat(input1) * 100000000), input2], //
      },
    };
    try {
      const response = await signAndSubmitTransaction(transaction);
      await aptosClient(network).waitForTransaction({
        transactionHash: response.hash,
      });
      toast({
        title: "Success",
        description: <TransactionHash hash={response.hash} network={network} />,
      });

      // Update the API call to use the new endpoint
      try {
        console.log('Network object:', network); // Log the entire network object
        const networkName = network?.name?.toLowerCase() || 'unknown';
        console.log('Network name:', networkName); // Log the network name

        const serverResponse = await axios.post(`${API_URL}/settle-attack`, {
          address: account.address,
          transactionHash: response.hash,
          network: networkName
        });
        console.log('Server response:', serverResponse.data);
        setLastTransactionTime(Date.now());
      } catch (serverError) {
        console.error('Error calling server:', serverError);
        toast({
          title: "Error",
          description: 'Failed to settle attack on server',
        });
      }
    } catch (error) {
      console.error('Transaction error:', error);
      toast({
        title: "Error",
        description: 'Transaction failed',
      });
    }
  };
  const handleInputChange1 = (event: React.ChangeEvent<HTMLInputElement>) => {
    setInput1(event.target.value.replace(/[^\d\.]/g, ''));
  };

  const adjustInput = (adjustment: number) => {
    const balance = parseInt(playerBalance) / 100000000;
    const currentValue = parseFloat(input1) || 0;
    const newValue = Math.max(0, currentValue + balance * adjustment);
    setInput1(newValue.toFixed(5));
  };

  const formatNumber = (num: number) => num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");

  return (
    <div className="flex flex-col lg:flex-row gap-4 w-full max-w-7xl mx-auto">
      <Card className="bg-black text-yellow-100 border-yellow-300 border-2 flex-1 lg:w-2/3">
      <MonsterStatus monster={monster} setMonster={setMonster} />
        
        <CardHeader>
          <CardTitle>Monster {parseInt(monster?.id ?? '0')}</CardTitle>
        </CardHeader>


        <CardContent className="flex flex-col gap-4">
          <div className="flex justify-between items-center">
            <div className="flex flex-col items-center">
              <p className="text-white mb-2">Your Balance: {(parseInt(playerBalance) / 100000000).toFixed(3)} Move</p>
              <div className="flex items-center">
                <Button
                  onClick={() => adjustInput(-0.2)}
                  className="h-8 px-2 py-0 text-xs bg-gray-700 hover:bg-gray-600"
                >
                  -20%
                </Button>
                <input
                  type="text"
                  id="input1"
                  value={input1}
                  onChange={handleInputChange1}
                  placeholder="VALUE"
                  className="bg-gray-800 text-white border border-yellow-300 rounded px-2 py-1 w-24 text-center mx-1"
                />
                <Button
                  onClick={() => adjustInput(0.2)}
                  className="h-8 px-2 py-0 text-xs bg-gray-700 hover:bg-gray-600"
                >
                  +20%
                </Button>
              </div>
              <label className="text-white mt-2">
                Potential Return: 
                <span className="inline-block min-w-[100px] ml-2">
                  {calculatePotentialReturn(
                    parseInt(monster?.defence ?? '0'),
                    parseInt(monster?.hp ?? '0'),
                    false
                  ).toFixed(5)}
                </span>
              </label>
            </div>

            <div className="flex flex-col items-center">

                <label htmlFor="input2" className="text-white">Win Rate: {100 - input2}%</label>
                <label className="text-white">
                  Estimate Damage: 
                  <span className="inline-block min-w-[100px] ml-2">
                    {formatNumber(parseInt(calculatePotentialReturn(
                      parseInt(monster?.defence ?? '0'),
                      parseInt(monster?.hp ?? '0'),
                      true
                    ).toFixed(0)))}
                  </span>
                </label>

              <div style={{width: '200px'}}>
                <Slider
                  min={1}
                  max={99}
                  value={input2}
                  onChange={(value: number | number[]) => {
                    if (typeof value === 'number') {
                      setInput2(value);
                    } else {
                      setInput2(value[0]);
                    }
                  }}
                  railStyle={{ backgroundColor: '#4B5563' }}
                  trackStyle={{ backgroundColor: '#EAB308' }}
                  handleStyle={{
                    borderColor: '#EAB308',
                    backgroundColor: '#EAB308',
                  }}
                />
              </div>
              <div className="mt-2">
                <Image 
                  src="/shield_sword.png"
                  alt="Shield and Sword"
                  width={220}
                  height={30}
                  className="object-contain"
                />
              </div>
            </div>
          </div>

          <div className="flex justify-center mt-4">
            <ASCIIButton onClick={() => onSignAndSubmitTransaction([])} disabled={!sendable} href={""}>
              Attack
            </ASCIIButton>
          </div>
        </CardContent>
      </Card>
      {connected && 
      
      <div className="lg:w-1/3 w-full">        
      <AttackHistory lastTransactionTime={lastTransactionTime} />
      
      </div>}
    </div>
  );
}
