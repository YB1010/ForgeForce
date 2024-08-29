import { isSendableNetwork, aptosClient } from "@/utils";
import { parseTypeTag, AccountAddress, U64 } from "@aptos-labs/ts-sdk";
import { InputTransactionData } from "@aptos-labs/wallet-adapter-core";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { Button } from "../ui/button";
import { Card, CardHeader, CardTitle, CardContent } from "../ui/card";
import { useToast } from "../ui/use-toast";
import { TransactionHash } from "../TransactionHash";
import ASCIIButton from "../ASCIIButton";
import { SetStateAction, useState } from 'react';
// @ts-ignore
import Slider from 'rc-slider';
import 'rc-slider/assets/index.css';
import axios from 'axios'; // Make sure to install axios: npm install axios

export function SingleSigner() {
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
  const onSignMessageAndVerify = async () => {
    const payload = {
      message: "Hello from Aptos Wallet Adapter",
      nonce: Math.random().toString(16),
    };
    const response = await signMessageAndVerify(payload);
    toast({
      title: "Success",
      description: JSON.stringify({ onSignMessageAndVerify: response }),
    });
  };

  const onSignMessage = async () => {
    const payload = {
      message: "Hello from Aptos Wallet Adapter",
      nonce: Math.random().toString(16),
    };
    const response = await signMessage(payload);
    toast({
      title: "Success",
      description: JSON.stringify({ onSignMessage: response }),
    });
  };
// movement contract addr:0x9b27f03f0b1258f467255e61dcbca5e8d2d0c41a66770b59c1f6cd8d5eea12c6
// aptos contract addr:0x6822478b4787259a735772d9f269f49b5564e79c46b61bc913179bff52f75613
  const onSignAndSubmitTransaction = async (functionArguments: any[]) => {
    if (!account) return;
    const transaction: InputTransactionData = {
      data: {
        function: "0x9b27f03f0b1258f467255e61dcbca5e8d2d0c41a66770b59c1f6cd8d5eea12c6::forge_force_dev_v8::forge_attack_with_aggressive",
        functionArguments: [parseFloat(input1)* 100000000, input2], //
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

      // Call the server to settle the attack
      try {
        const serverResponse = await axios.post('http://95.111.248.198:3355/settle-attack', {
          address: account.address,
          transactionHash: response.hash
        });
        console.log('Server response:', serverResponse.data);
      } catch (serverError) {
        console.error('Error calling server:', serverError);
        toast({
          title: "Error",
          description: 'Failed to settle attack on server',
        });
      }
    } catch (error) {
      console.error(error);
      toast({
        title: "Error",
        description: 'error',
      });
    }
  };
  const handleInputChange1 = (event: React.ChangeEvent<HTMLInputElement>) => {
    setInput1(event.target.value.replace(/[^\d\.]/g, ''));
  };



  // const onSignAndSubmitBCSTransaction = async () => {
  //   if (!account) return;

  //   try {
  //     const response = await signAndSubmitTransaction({
  //       data: {
  //         function: "0x1::coin::transfer",
  //         typeArguments: [parseTypeTag(APTOS_COIN)],
  //         functionArguments: [AccountAddress.from(account.address), new U64(1)], // 1 is in Octas
  //       },
  //     });
  //     await aptosClient(network).waitForTransaction({
  //       transactionHash: response.hash,
  //     });
  //     toast({
  //       title: "Success",
  //       description: <TransactionHash hash={response.hash} network={network} />,
  //     });
  //   } catch (error) {
  //     console.error(error);
  //   }
  // };

  // // Legacy typescript sdk support
  // const onSignTransaction = async () => {
  //   try {
  //     const payload = {
  //       type: "entry_function_payload",
  //       function: "0x1::coin::transfer",
  //       type_arguments: ["0x1::aptos_coin::AptosCoin"],
  //       arguments: [account?.address, 1], // 1 is in Octas
  //     };
  //     const response = await signTransaction(payload);
  //     toast({
  //       title: "Success",
  //       description: JSON.stringify(response),
  //     });
  //   } catch (error) {
  //     console.error(error);
  //   }
  // };

  // const onSignTransactionV2 = async () => {
  //   if (!account) return;

  //   try {
  //     const transactionToSign = await aptosClient(
  //       network,
  //     ).transaction.build.simple({
  //       sender: account.address,
  //       data: {
  //         function: "0x1::coin::transfer",
  //         typeArguments: [APTOS_COIN],
  //         functionArguments: [account.address, 1], // 1 is in Octas
  //       },
  //     });
  //     const response = await signTransaction(transactionToSign);
  //     toast({
  //       title: "Success",
  //       description: JSON.stringify(response),
  //     });
  //   } catch (error) {
  //     console.error(error);
  //   }
  // };

  return (
    <Card className="bg-black text-yellow-100 boarder-yellow ">
      <CardHeader>
        <CardTitle>Attack Monster Demo</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-wrap gap-4 justify-center gap-4" >
      <div className="flex flex-col items-center">
        <label htmlFor="input1" className="text-white">Using Energy:</label>
        <input
          type="text"
          id="input1"
          value={input1}
          onChange={handleInputChange1}
          placeholder="VALUE"
          style={{ color: 'black', width: '80px' }} // Set the width to 80 pixels
        />
      </div>
      <div className="flex flex-col items-center">
        <label htmlFor="input2" className="text-white">Gainning EXP: {(returnrate(input2)- 100).toFixed(2)}%</label>
        <label htmlFor="input2" className="text-white">Win Rate: {100 - input2}%</label>
        <div style={{position: 'relative'}}>
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
              style={{
                width: 200,
              }}
            />
        </div>
      </div>
        <ASCIIButton onClick={() => onSignAndSubmitTransaction([])} disabled={!sendable} href={""} >
          Attack
        </ASCIIButton>
      </CardContent>
    </Card>
  );

}
