require('dotenv').config();
const express = require('express');
const { Account, Aptos, AptosConfig, Network, Ed25519PrivateKey } = require("@aptos-labs/ts-sdk");
const cors = require('cors');
const Queue = require('bull');
const crypto = require('crypto');

const app = express();

// CORS configuration
const corsOptions = {
  origin: process.env.FRONTEND_URL || 'https://forge-force.vercel.app/',
  optionsSuccessStatus: 200
};

app.use(cors(corsOptions));
app.use(express.json());

const config = new AptosConfig({ network: Network.TESTNET });
const aptos = new Aptos(config);

// Use the private key from .env

const privateKey = new Ed25519PrivateKey(process.env.APTOS_PRIVATE_KEY); //variable name must be privateKey
const account = Account.fromPrivateKey({ privateKey });

// Create a new queue using REDIS_URL from .env
const settleAttackQueue = new Queue('settleAttack', process.env.REDIS_URL);

// Function to generate a random number
const generateRandomNumber = () => {
  return crypto.randomInt(1, 99); // Generates a random integer between 1 and 99
};

app.post('/settle-attack', async (req, res) => {
  const { address, transactionHash } = req.body;

  if (!address || !transactionHash) {
    return res.status(400).json({ success: false, error: 'Missing required parameters' });
  }

  try {
    const randomNumber = generateRandomNumber();
    await settleAttackQueue.add({ address, transactionHash, randomNumber });
    res.json({ success: true, message: 'Request queued for processing' });
  } catch (error) {
    console.error('Error queueing settle-attack request:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Process jobs from the queue
settleAttackQueue.process(async (job) => {
  const { address, transactionHash, randomNumber } = job.data;

  try {
    const transaction = await aptos.transaction.build.simple({
      sender: account.accountAddress,
      data: {
        function: "0x9b27f03f0b1258f467255e61dcbca5e8d2d0c41a66770b59c1f6cd8d5eea12c6::forge_force_dev::settle_attack",
        functionArguments: [address, randomNumber.toString()],
        typeArguments: [],
      },
    });

    const signature = aptos.transaction.sign({ signer: account, transaction });

    const committedTxn = await aptos.transaction.submit.simple({
      transaction,
      senderAuthenticator: signature,
    });

    console.log(`Submitted transaction: ${committedTxn.hash}`);
    const response = await aptos.waitForTransaction({ transactionHash: committedTxn.hash });

    console.log(`Settled attack for ${address}, random number: ${randomNumber}, hash: ${committedTxn.hash}`);
    return { success: true, hash: committedTxn.hash };
  } catch (error) {
    console.error(`Error settling attack for ${address}:`, error);
    throw error; // This will cause the job to be retried
  }
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));