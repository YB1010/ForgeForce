require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { Account, Aptos, AptosConfig, Network, Ed25519PrivateKey } = require("@aptos-labs/ts-sdk");
const Queue = require('bull');
const crypto = require('crypto');

const app = express();

// CORS configuration
const corsOptions = {
  origin: function (origin, callback) {
    const allowedOrigins = [
      process.env.FRONTEND_URL,
      'https://forge-force.vercel.app',
      'http://localhost:3000',
      'https://helloapple.xyz'
    ].filter(Boolean);
    
    if (!origin || allowedOrigins.indexOf(origin) !== -1) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  optionsSuccessStatus: 200
};

app.use(cors(corsOptions));
app.use(express.json());

// Function to get Aptos configuration based on network parameter
function getAptosConfig(network) {
  if (network.name === 'custom') {
    return new AptosConfig({ 
      network: Network.CUSTOM,
      fullnode: network.url
    });
  } else {
    // Default to TESTNET if network is not specified or recognized
    return new AptosConfig({ network: Network.TESTNET });
  }
}

// Initialize with default config (you can choose either TESTNET or Movement)
let aptos = new Aptos(getAptosConfig('testnet'));

// Use the private key from .env
const privateKey = new Ed25519PrivateKey(process.env.APTOS_PRIVATE_KEY);
const account = Account.fromPrivateKey({ privateKey });

// Create a new queue using REDIS_URL from .env
const settleAttackQueue = new Queue('settleAttack', process.env.REDIS_URL);

// Function to generate a random number
const generateRandomNumber = () => {
  return crypto.randomInt(1, 99);
};

// Root route
app.get('/', (req, res) => {
  res.send('Welcome to the Forge Force server!');
});

// Update the /settle-attack route to accept a network parameter
app.post('/settle-attack', async (req, res) => {
  const { address, transactionHash, network } = req.body;

  if (!address || !transactionHash) {
    return res.status(400).json({ success: false, error: 'Missing required parameters' });
  }

  // Update Aptos configuration based on the provided network
  aptos = new Aptos(getAptosConfig(network));

  try {
    const randomNumber = generateRandomNumber();
    await settleAttackQueue.add({ address, transactionHash, randomNumber, network });
    res.json({ success: true, message: 'Request queued for processing' });
  } catch (error) {
    console.error('Error queueing settle-attack request:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

const PORT = process.env.PORT || 3355;
app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});

// Process jobs from the queue
settleAttackQueue.process(async (job) => {
  const { address, transactionHash, randomNumber, network } = job.data;

  // Update Aptos configuration based on the network from the job data
  aptos = new Aptos(getAptosConfig(network));

  try {
    const transaction = await aptos.transaction.build.simple({
      sender: account.accountAddress,
      data: {
        function: "0x9b27f03f0b1258f467255e61dcbca5e8d2d0c41a66770b59c1f6cd8d5eea12c6::forge_force_dev_v8::settle_attack",
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
