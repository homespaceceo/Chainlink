import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("HomespaceLandNFT", function () {
  async function prepare() {
    // Define signers
    const [owner, userOne, userTwo, paymentReceiver] = await ethers.getSigners();

    // Deploy Mocks
    const MockLinkToken = await ethers.getContractFactory("MockLinkToken");
    const linkToken = await MockLinkToken.deploy();
    await linkToken.deployed();

    const MockVRFV2Wrapper = await ethers.getContractFactory(
      "MockVRFV2Wrapper"
    );
    const mockVRFWrapper = await MockVRFV2Wrapper.deploy();
    await mockVRFWrapper.deployed();

    const MockToken = await ethers.getContractFactory(
      "MockToken"
    );
    const usdtToken = await MockToken.deploy();
    await usdtToken.deployed();

    // Deploy Traits
    const HomespaceLandNFT = await ethers.getContractFactory(
      "HomespaceLandNFT"
    );
    const ERC1967Proxy = await ethers.getContractFactory(
      "ERC1967Proxy"
    );
    const nftImpl = await HomespaceLandNFT.deploy()
    await nftImpl.deployed();
    const nftProxy = await ERC1967Proxy.deploy(nftImpl.address, "0x")
    await nftProxy.deployed();

    const nft = HomespaceLandNFT.attach(nftProxy.address)
    await nft.initialize(
      "Homespace Domain Lands",
      "HDL",
      "https://google.com/",
      linkToken.address,
      mockVRFWrapper.address,
      usdtToken.address,
      paymentReceiver.address
    )

    return {
      owner, userOne, userTwo, paymentReceiver,
      linkToken, mockVRFWrapper,
      usdtToken,
      nft
    };
  }

  describe("Deployment", function () {
    it("Should be deployed with correct initial values", async function () {
      const { nft } = await loadFixture(prepare);

      expect(await nft.version()).to.equal(2);
    });
  });

  describe("NFT", function () {
    it("Should work", async function () {
      const {
        userOne, userTwo, paymentReceiver,
        linkToken, usdtToken,
        mockVRFWrapper,
        nft
      } = await loadFixture(prepare);

      // CONFIG: Set NFT price
      const PRICE = ethers.utils.parseUnits('199', 6);
      await nft.setPrice(PRICE);

      // TEST: Transfer test tokens to users
      await usdtToken.transfer(userOne.address, PRICE);
      await usdtToken.transfer(userTwo.address, PRICE.mul(2));

      // CONFIG: fill unassigned land Ids
      const fillTx = await nft.fillUnassignedLandIds(1, 1100);
      const fillReceipt = await fillTx.wait();

      // CONFIG: Fund account with LINK token
      const ONE_LINK = ethers.utils.parseEther("1");
      await linkToken.mint(nft.address, ONE_LINK.mul(3));

      //// PURCHASE #1
      // TEST: Purchase NFT + Request Randomness
      await usdtToken.connect(userOne).approve(nft.address, PRICE);
      await nft.connect(userOne).mint(1);
      expect(await usdtToken.balanceOf(paymentReceiver.address)).to.be.equal(PRICE.mul(1));

      // TEST: Provide randomness: Simulate Chainlink
      const randomWord = 1337
      const tx = await mockVRFWrapper.provide(nft.address, 1, [randomWord]);
      const recipe = await tx.wait()
      console.log({ gas_used: recipe.gasUsed })

      const landIdOne = randomWord % 1100 + 1;

      expect(await nft.tokenIdToLandId(1)).to.be.equal(landIdOne);

      //// PURCHASE #3
      // TEST: Purchase NFT + Request Randomness
      await usdtToken.connect(userTwo).approve(nft.address, PRICE.mul(2));
      await nft.connect(userTwo).mint(2);
      expect(await usdtToken.balanceOf(paymentReceiver.address)).to.be.equal(PRICE.mul(3));

      // TEST: Provide randomness: Simulate Chainlink
      await mockVRFWrapper.provide(nft.address, 2, [randomWord]);
      await mockVRFWrapper.provide(nft.address, 3, [randomWord]);

      const landIdTwo = landIdOne + 1;
      const landIdThree = landIdTwo + 1;

      expect(await nft.tokenIdToLandId(2)).to.be.equal(landIdTwo);
      expect(await nft.tokenIdToLandId(3)).to.be.equal(landIdThree);
    });
  });
});
