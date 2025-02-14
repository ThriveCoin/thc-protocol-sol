const axios = require('axios')
const { ethers } = require('ethers')

const PRIVATE_KEY = process.env.PRIVATE_KEY
const RPC_URL = process.env.RPC_URL
const COMMUNITY_CONTRACTS = {
  31: '0xNativeCommunityContract', // Native (THRIVE)
  20: '0xApeCommunityContract', // Ape
  36: '0xArbCommunityContract' // Hedera
}
const API_URL = process.env.API_URL

const provider = new ethers.JsonRpcProvider(RPC_URL)
const wallet = new ethers.Wallet(PRIVATE_KEY, provider)
const ABI = [
  'event ContributionDataRequested(address indexed user, uint256 communityId)',
  'function fulfillContributionData(address user, uint256 percentage) external'
]

async function fulfillContributionData (user, communityId, percentage) {
  if (!COMMUNITY_CONTRACTS[communityId]) {
    console.error(`No contract found for community ID: ${communityId}`)
    return
  }

  const contract = new ethers.Contract(COMMUNITY_CONTRACTS[communityId], ABI, wallet)

  try {
    const tx = await contract.fulfillContributionData(user, percentage)
    console.log(`Transaction sent: ${tx.hash}`)
    await tx.wait()
    console.log(`Contribution fulfilled for ${user} in community ${communityId}`)
  } catch (error) {
    console.error('Error fulfilling contribution data:', error)
  }
}

async function fetchUserContribution (user, communityId) {
  try {
    const response = await axios.get(`${API_URL}/${communityId}/${user}`)

    return response.data.percentage
  } catch (error) {
    console.error('API Error:', error.message)
    return 0
  }
}

async function listenForRequests () {
  for (const [, contractAddress] of Object.entries(COMMUNITY_CONTRACTS)) {
    const contract = new ethers.Contract(contractAddress, ABI, provider)

    contract.on('ContributionDataRequested', async (user, communityId) => {
      console.log(`Received request for ${user} in community ${communityId}`)

      const percentage = await fetchUserContribution(user, communityId)
      if (percentage > 0) {
        await fulfillContributionData(user, communityId, percentage)
      }
    })

    console.log(`Listening for ContributionDataRequested events on ${contractAddress}`)
  }
}

listenForRequests()
