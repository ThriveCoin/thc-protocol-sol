require("dotenv").config();
const express = require("express");
const axios = require("axios");
const { ethers } = require("ethers");

const PRIVATE_KEY = process.env.PRIVATE_KEY;
const RPC_URL = process.env.RPC_URL;
const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS;
const API_URL = process.env.API_URL;

const provider = new ethers.JsonRpcProvider(RPC_URL);
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
const abi = [
    "event ContributionDataRequested(address indexed user, uint256 requestId)",
    "function fulfillContributionData(uint256 requestId, uint256 reward) external"
];
const contract = new ethers.Contract(CONTRACT_ADDRESS, abi, wallet);

const app = express();
app.use(express.json());

console.log("🔍 Listening for ContributionDataRequested events...");

contract.on("ContributionDataRequested", async (user, requestId) => {
    console.log(`📢 New Request: User: ${user}, Request ID: ${requestId}`);

    try {
        const response = await axios.get(`${API_URL}/${user}`);
        const contributionPercentage = response.data.percentage;

        console.log(`✅ Contribution Percentage for ${user}: ${contributionPercentage}%`);

        const tx = await contract.fulfillContributionData(requestId, ethers.parseUnits(contributionPercentage.toString(), 18));
        await tx.wait();

        console.log(`🎉 Contribution data submitted on-chain for ${user}`);
    } catch (error) {
        console.error("❌ Error fetching/sending contribution data:", error.message);
    }
});

app.listen(3000, () => {
    console.log("🚀 Oracle Node is running on port 3000");
});
