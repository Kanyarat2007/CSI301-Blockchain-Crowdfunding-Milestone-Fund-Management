import { ethers } from "ethers";
export const ADDRESS = import.meta.env.VITE_CONTRACT_ADDRESS || "";
export const CHAIN_ID = Number(import.meta.env.VITE_CHAIN_ID || 11155111);
const infuraId = import.meta.env.VITE_INFURA_PROJECT_ID || "";
export const readProvider = infuraId
  ? new ethers.JsonRpcProvider(
      `https://sepolia.infura.io/v3/${infuraId}`,
      CHAIN_ID,
    )
  : null;
export const ABI = [
  "function admin() view returns (address)",
  "function campaignCount() view returns (uint256)",
  "function campaigns(uint256) view returns (address creator,string title,string description,uint256 goal,uint256 deadline,uint256 raised,uint256 released,uint256 refunded,uint256 milestoneCount)",
  "function contributions(uint256,address) view returns (uint256)",
  "function hasVoted(uint256,uint256,address) view returns (bool)",
  "function getMilestone(uint256,uint256) view returns (tuple(string title,uint256 amount,string evidence,uint256 approvals,uint256 rejections,uint256 votingPowerSnapshot,uint256 voteDeadline,bool requested,bool paid))",
  "function createCampaign(string,string,uint256,uint256,string[],uint256[]) returns (uint256)",
  "function contribute(uint256) payable",
  "function requestRelease(uint256,uint256,string)",
  "function vote(uint256,uint256,bool)",
  "function release(uint256,uint256)",
  "function refund(uint256)",
  "event CampaignCreated(uint256 indexed id,address indexed creator,string title,uint256 goal)",
  "event Contributed(uint256 indexed id,address indexed contributor,uint256 amount)",
  "event ReleaseRequested(uint256 indexed id,uint256 indexed milestone,string evidence)",
  "event Voted(uint256 indexed id,uint256 indexed milestone,address indexed voter,bool approve,uint256 weight)",
  "event FundsReleased(uint256 indexed id,uint256 indexed milestone,uint256 amount)",
  "event Refunded(uint256 indexed id,address indexed backer,uint256 amount)",
];
export const readContract = () => {
  if (!ADDRESS || !readProvider)
    throw Error("กรุณาตั้งค่า .env สำหรับ Contract และ Infura");
  return new ethers.Contract(ADDRESS, ABI, readProvider);
};
export const writeContract = async () => {
  if (!window.ethereum) throw Error("กรุณาติดตั้ง MetaMask");
  const p = new ethers.BrowserProvider(window.ethereum);
  const network = await p.getNetwork();
  if (Number(network.chainId) !== CHAIN_ID)
    throw Error(
      "กรุณาเปลี่ยนเครือข่าย MetaMask เป็น Sepolia (Chain ID 11155111)",
    );
  return new ethers.Contract(ADDRESS, ABI, await p.getSigner());
};
export const eth = (v) =>
  Number(ethers.formatEther(v || 0)).toLocaleString("en-US", {
    maximumFractionDigits: 5,
  });
