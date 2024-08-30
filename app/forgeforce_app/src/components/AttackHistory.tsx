import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { Aptos, AptosConfig, Network } from "@aptos-labs/ts-sdk";
import { Card, CardHeader, CardTitle, CardContent } from "./ui/card";
import { aptosClient } from "@/utils";
interface AttackHistoryItem {
  aggressive: string;
  bonus: string;
  effective_amount: string;
  final_damage: string;
  monster_id: string;
  raffle_id: string;
  random_number: string;
  sampled: boolean;
  stake_amount: string;
}
interface AttackHistoryProps {
    lastTransactionTime: number | null;
  }
  
const AttackHistory = ({ lastTransactionTime }: { lastTransactionTime: number | null }) => {
  const [attackHistory, setAttackHistory] = useState<AttackHistoryItem[]>([]);
  const { account, connected, network } = useWallet();

  const aptos = useMemo(() => {
    return aptosClient(network);
  }, [network]);

  const fetchAttackHistory = useCallback(async () => {
    if (!account) return;
    try {
      const history = await aptos.view({
        payload: {
          function: "0x9b27f03f0b1258f467255e61dcbca5e8d2d0c41a66770b59c1f6cd8d5eea12c6::forge_force_dev_v8::get_player_attack_history",
          typeArguments: [],
          functionArguments: [account.address],
        },
      }) as AttackHistoryItem[][];
      
      const sortedHistory = history.map(innerArray => 
        innerArray.sort((a, b) => parseInt(b.raffle_id) - parseInt(a.raffle_id))
      );
      console.log("Sorted history:", sortedHistory);
      setAttackHistory(sortedHistory.flat());
    } catch (error) {
      console.error("Error fetching attack history:", error);
    }
  }, [aptos, account]);

  useEffect(() => {
    if (connected && account) {
      fetchAttackHistory();
    }
  }, [connected, account, fetchAttackHistory]);

  useEffect(() => {
    if (connected && account && lastTransactionTime) {
      const timeoutId = setTimeout(() => {
        fetchAttackHistory();
      }, 10000); // 10 seconds delay

      return () => clearTimeout(timeoutId);
    }
  }, [connected, account, lastTransactionTime, fetchAttackHistory]);

  const formatNumber = (num: string) => {
    return parseInt(num).toLocaleString();
  };

  console.log("Rendering AttackHistory component. Current state:", attackHistory);

  return (
    <Card className="bg-black text-yellow-100 border-yellow-300 border-2">
      <CardHeader>
        <CardTitle>Attack History</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="h-96 overflow-y-auto">
          {attackHistory.length === 0 ? (
            <p>No attack history available.</p>
          ) : (
            <ul>
              {attackHistory.map((historyItem, index) => (
                <React.Fragment key={index}>
                  <li key={historyItem.raffle_id} className="mb-4 border-b border-yellow-300 pb-2">
                    <p>Raffle ID: {historyItem.raffle_id}</p>
                    <p>Monster ID: {historyItem.monster_id}</p>
                    <p>Staked Amount: {parseFloat(historyItem.stake_amount) / 100000000}</p>
                    <p>Win Rate: {100 - parseFloat(historyItem.aggressive)}%</p>
                    {historyItem.sampled ? (
                      <>
                        <p className={parseInt(historyItem.final_damage) > 0 ? 'text-green-500' : 'text-red-500'}>
                          {parseInt(historyItem.final_damage) > 0 ? 'Success' : 'Failure'}
                        </p>
                        <p>Final Damage: {formatNumber(historyItem.final_damage)}</p>
                      </>
                    ) : (
                      <p className="text-yellow-500">Pending</p>
                    )}
                  </li>
                </React.Fragment>
              ))}
            </ul>
          )}
        </div>
      </CardContent>
    </Card>
  );
};

export default AttackHistory;