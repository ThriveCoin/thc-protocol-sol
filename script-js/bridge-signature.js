'use strict'

const { ethers } = require('ethers')
const yargs = require('yargs')
  .option('contract', { alias: 'c', type: 'string', demandOption: true })
  .option('sender', { alias: 's', type: 'string', demandOption: true })
  .option('receiver', { alias: 'r', type: 'string', demandOption: true })
  .option('nonce', { alias: 'n', type: 'number', demandOption: true })
  .option('amount', { alias: 'a', type: 'string', demandOption: true })

const main = async () => {
  const argv = yargs.argv
  const provider = new ethers.JsonRpcProvider(process.env.RPC_URL)
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider)
  console.log('Wallet address:', wallet.address)

  const srcContract = argv.contract
  const sender = argv.sender
  const receiver = argv.receiver
  const nonce = argv.nonce
  const amount = argv.amount

  const hash = ethers.keccak256(
    ethers.solidityPacked(
      ["address", "address", "address", "uint256", "uint256"],
      [srcContract, sender, receiver, nonce, amount]
    )
  )
  const ethSignedMessageHash = ethers.hashMessage(ethers.getBytes(hash))
  const signature = await wallet.signMessage(ethers.getBytes(hash))

  console.log("Hash:", hash)
  console.log("Ethereum Signed Message Hash:", ethSignedMessageHash)
  console.log("Signature:", signature)

  const sigBytes = ethers.Signature.from(signature)
  console.log("r:", sigBytes.r)
  console.log("s:", sigBytes.s)
  console.log("v:", sigBytes.v)

  const recoveredAddress = ethers.verifyMessage(ethers.getBytes(hash), signature)
  console.log("Recovered Address:", recoveredAddress)
}

main()
