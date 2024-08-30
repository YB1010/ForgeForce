import React, { useState, useEffect, useCallback } from 'react';
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { Aptos, AptosConfig, Network } from "@aptos-labs/ts-sdk";
import { aptosClient } from "@/utils"; // Import the aptosClient function
import Image from 'next/image';

interface Monster {
  id: string;
  hp: string;
  max_hp: string;
  defence: string;
}

interface MonsterStatusProps {
    monster: Monster | null;
    setMonster: React.Dispatch<React.SetStateAction<Monster | null>>;
}

const MonsterStatus: React.FC<MonsterStatusProps> = ({ monster: initialMonster, setMonster }) => {
  const [isHovered, setIsHovered] = useState(false);
  const [monster, setMonsterState] = useState<Monster | null>(initialMonster);
  const { network } = useWallet();

  const fetchMonster = useCallback(async () => {
    const aptos = aptosClient(network);

    try {
      const monsterList = await aptos.view({
        payload: {
          function: "0x9b27f03f0b1258f467255e61dcbca5e8d2d0c41a66770b59c1f6cd8d5eea12c6::forge_force_dev_v8::get_monster_list",
          typeArguments: [],
          functionArguments: [],
        },
      });

      if (monsterList && monsterList[0]?.data?.length > 0) {
        const monsters = monsterList[0].data;
        let id = monsterList[0].data.length;
        const latestMonster = monsters.reduce((latest, current) => 
          parseInt(current.key) > parseInt(latest.key) ? current : latest
        );
        const newMonster = { ...latestMonster.value, id: latestMonster.key } as Monster;
        setMonsterState(newMonster);
        setMonster(newMonster); // Update the parent's monster state
        console.log('Updated monster:', newMonster);
      }
    } catch (error) {
      console.error("Error fetching monster:", error);
    }
  }, [network, setMonster]);

  useEffect(() => {
    fetchMonster();
    const intervalId = setInterval(fetchMonster, 10000);
    return () => clearInterval(intervalId);
  }, [fetchMonster]);

  const renderHPBar = (hp: number, maxHp: number) => {
    const percentage = (hp / maxHp) * 100;
    const filledWidth = Math.round((percentage / 100) * 20);
    const emptyWidth = 20 - filledWidth;

    return `${'█'.repeat(filledWidth)}${'░'.repeat(emptyWidth)}`;
  };

  return (
    <div className="font-mono text-yellow-300 mt-4">
      {monster && (
        <>
          <p className="text-center mt-2">
            HP: {parseInt(monster.hp).toLocaleString()} / {parseInt(monster.max_hp).toLocaleString()}
          </p>
          <pre className="whitespace-pre-wrap">
            {renderHPBar(parseInt(monster.hp), parseInt(monster.max_hp))}
          </pre>
          
          <p className="text-center mt-2">
            DEF: {parseInt(monster.defence).toLocaleString()}
          </p>

          <div 
            className="relative w-40 h-40 mx-auto mt-4"
            onMouseEnter={() => setIsHovered(true)}
            onMouseLeave={() => setIsHovered(false)}
          >
            <Image 
              src={`/monster${isHovered ? '.gif' : '.png'}`}
              alt="Monster"
              width={160}
              height={160}
              className="object-contain"
            />
          </div>

        </>
      )}
    </div>
  );
};

export default MonsterStatus;