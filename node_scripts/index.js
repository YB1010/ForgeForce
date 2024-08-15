const { Account, Aptos, AptosConfig, Network, Ed25519PrivateKey } = require("@aptos-labs/ts-sdk");

const dotenv = require("dotenv");

dotenv.config();

const PRIVATE_KEY = process.env.my_PRIVATE_KEY;
console.log(PRIVATE_KEY);
const MODULE_ADDRESS = process.env.MODULE_ADDRESS;



const MODULE_NAME = "forge_force_dev";
const FUNCTION_NAME = `${MODULE_ADDRESS}::forge_force_dev::raffle_with_aggre`;


const config = new AptosConfig({
    network:Network.TESTNET
})



async function main() {
  
  const client = new Aptos(config);

  if (process.argv.length !== 4) {
    console.error("Usage: node raffle.js <amount> <aggressive>");
    process.exit(1);
  }

  const amount = parseInt(process.argv[2]);
  const aggressive = parseInt(process.argv[3]);

  if (isNaN(amount) || isNaN(aggressive)) {
    console.error("Amount and aggressive must be valid numbers");
    process.exit(1);
  }

  // Load the account from the private key
  const privateKey = new Ed25519PrivateKey(PRIVATE_KEY);

  const account = Account.fromPrivateKey({ privateKey }); //the constant variable name must be privateKey? Otherwise, it will be error.


  const accountAddress = account.accountAddress;


  console.log(`Using account: ${accountAddress}`);  



  // Submit the transaction

  const transaction = await client.transaction.build.simple({
    sender: accountAddress,
    data: {
      function: FUNCTION_NAME,
      functionArguments: [amount,aggressive]
    },
  });
  const signature = client.transaction.sign({ signer: account, transaction });
  const committedTxn = await client.transaction.submit.simple({
    transaction,
    senderAuthenticator: signature,
  });
  console.log(`Submitted transaction: ${committedTxn.hash}`);
  const response = await client.waitForTransaction({ transactionHash: committedTxn.hash });
  console.log({ response })
// todo:get this event of this transaction   
//const events = await client.getEvents({options: { where: { account_address: { accountAddress } } }});
//   console.log({ events })

}

main().then(() => process.exit(0)).catch((error) => {
  console.error(error);
  process.exit(1);
});