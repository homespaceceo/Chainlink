import { ethers } from "hardhat";

const LINK_TOKEN_ADDRESS = '0x326C977E6efc84E512bB9C30f76E30c160eD06FB'
const VFR_WRAPPER_ADDRESS = '0x99aFAf084eBA697E584501b8Ed2c0B37Dd136693'

const PAYMENT_RECEIVER = "<YOUR_ADDRESS_HERE>"

const NAME = "Homespace Domain Lands Test"
const SYMBOL = "HDLT"

const BASE_URI = "https://homespace-land-metadata-ul3ybjytha-ez.a.run.app/"

async function main() {
  // TEST: Deployment
  const MockToken = await ethers.getContractFactory(
    "MockToken"
  );
  const usdtToken = await MockToken.deploy({ gasLimit: 1_000_000 });
  await usdtToken.deployed();
  console.log(`Mock USDT deployed @ ${usdtToken.address}`);

  // PROD: Deployment
  const HomespaceLandNFT = await ethers.getContractFactory(
    "HomespaceLandNFT"
  );
  const ERC1967Proxy = await ethers.getContractFactory(
    "ERC1967Proxy"
  );
  const nftImpl = await HomespaceLandNFT.deploy({ gasLimit: 4_000_000 });
  await nftImpl.deployed();
  console.log(`NFT Implementation deployed @ ${nftImpl.address}`);

  const nftProxy = await ERC1967Proxy.deploy(nftImpl.address, "0x", { gasLimit: 1_000_000 });
  await nftProxy.deployed();
  console.log(`NFT Proxy deployed @ ${nftProxy.address}`);

  const nft = HomespaceLandNFT.attach(nftProxy.address);
  await nft.initialize(
    NAME, SYMBOL,
    BASE_URI,
    LINK_TOKEN_ADDRESS,
    VFR_WRAPPER_ADDRESS,
    usdtToken.address,
    PAYMENT_RECEIVER,
    { gasLimit: 1_000_000 }
  )
  console.log(`NFT Proxy initialized`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
