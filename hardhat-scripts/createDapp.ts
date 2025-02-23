import * as dotenv from 'dotenv'
dotenv.config()

import { Identity } from '@semaphore-protocol/identity'
import ethers, { Contract, providers, Wallet } from 'ethers'

async function main() {
    const dappIdentity = new Identity('stripeTLS')
    console.log(dappIdentity)
    const { nullifier } = dappIdentity

    const arbReclaimAddress =
        "0x4D1ee04EB5CeE02d4C123d4b67a86bDc7cA2E62A";
    const optReclaimAddress =
        "0x47dC7a593A857f906f19dE09c44DedCdC02Dc991";

    const reclaimAbi = [
        "function createDapp(uint256 id) external",
        "event DappCreated(bytes32 indexed dappId)"
    ];
    const arbReclaim = new Contract(arbReclaimAddress, reclaimAbi);
    const optReclaim = new Contract(optReclaimAddress, reclaimAbi);

    // Import private key from environment variable
    const PRIVATE_KEY = process.env.PRIVATE_KEY
    if (!PRIVATE_KEY) {
        throw new Error("Please set PRIVATE_KEY environment variable")
    }

    // Create provider and signer
    const provider = new providers.JsonRpcProvider(process.env.OPTIMISM_SEPOLIA_RPC)

    const signer = new Wallet(PRIVATE_KEY, provider)
    const createDappTransactionResponse = await optReclaim.connect(signer).createDapp(
        nullifier
    )

    const createDappTransactionReceipt =
        await createDappTransactionResponse.wait()

    console.log(createDappTransactionReceipt.transactionHash)
    const dappId = createDappTransactionReceipt.events![0]!.args![0]!

    console.log('External Nullifier:', nullifier.toString())
    console.log('Dapp Id:', dappId)
}

//  dapp  id 
//  0xa05be1ad5952483191c8ae5e0f0d56b81a677cf55ac15041f6acabd13201fb95
main()