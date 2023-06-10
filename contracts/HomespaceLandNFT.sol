// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { StringsUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFV2WrapperInterface.sol";

contract HomespaceLandNFT is Initializable, UUPSUpgradeable, AccessControlUpgradeable, OwnableUpgradeable, ERC721Upgradeable {
    /** Libraries */
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using StringsUpgradeable for uint256;

    /** CONSTANTS */
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    uint256 public constant MINTABLE_SUPPLY = 250;
    uint256 public constant LIMIT_PER_ADDRESS = 2;

    /** --- BEGIN: V1 Storage Layout --- */
    // Chainlink VRF
    LinkTokenInterface public LINK;
    VRFV2WrapperInterface public VRF_V2_WRAPPER;
    mapping (uint256 => uint256) public tokenIdToRandomWord;
    mapping (uint256 => uint256) public randomRequestIdToTokenId;

    // NFT
    string public baseURI;
    address payable public paymentReceiver;
    IERC20Upgradeable public purchaseToken;
    uint256[] public unassignedLandIds;
    uint256 public totalMinted;
    uint256 public price;
    mapping (uint256 => uint256) public tokenIdToLandId;
    mapping (address => uint256) public tokensPerAddress;

    /** --- END: V1 Storage Layout --- */

    /** INITIALIZATION & MAINTENANCE */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name_, string memory symbol_,
        string memory baseURI_,
        address link_, address vrfV2Wrapper_,
        address purchaseToken_, address payable paymentReceiver_
    ) public initializer {
        __ERC721_init(name_, symbol_);
        __AccessControl_init();
        __Ownable_init();
        __UUPSUpgradeable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(UPGRADER_ROLE, _msgSender());

        // Chainlink VRF
        LINK = LinkTokenInterface(link_);
        VRF_V2_WRAPPER = VRFV2WrapperInterface(vrfV2Wrapper_);

        // NFT
        baseURI = baseURI_;
        purchaseToken = IERC20Upgradeable(purchaseToken_);
        paymentReceiver = paymentReceiver_;
    }

    function version() external pure returns (uint256) {
        return 2;
    }

    function getImplementation() external view returns (address) {
        return _getImplementation();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    /** PUBLIC GETTERS */
    function supportsInterface(bytes4 interfaceId) public view override(ERC721Upgradeable, AccessControlUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function contractURI() external view returns (string memory) {
        return string(abi.encodePacked(
            _baseURI(),
            "contract"
        ));
    }

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        return string(abi.encodePacked(
            _baseURI(),
            tokenIdToLandId[_tokenId].toString()
        ));
    }

    function uri(uint256 _tokenId) external view virtual returns (string memory) {
        return string(abi.encodePacked(
            _baseURI(),
            tokenIdToLandId[_tokenId].toString()
        ));
    }

    /** PUBLIC SETTERS */
    // Guarded
    function fillUnassignedLandIds(uint256 from_, uint256 to_) external onlyRole(UPGRADER_ROLE) {
        for (uint256 index = from_; index <= to_; index++) {
            unassignedLandIds.push(index);
        }
    }

    function setPrice(uint256 price_) external onlyRole(UPGRADER_ROLE) {
        price = price_;
    }

    function withdraw() external onlyRole(UPGRADER_ROLE) {
        uint256 balance = address(this).balance;
        payable(_msgSender()).transfer(balance);
    }

    function rescueFunds(address token_) external onlyRole(UPGRADER_ROLE) {
        IERC20Upgradeable token = IERC20Upgradeable(token_);
        uint256 balance = token.balanceOf(address(this));
        token.transfer(_msgSender(), balance);
    }

    function setBaseURI(string memory baseURI_) external onlyRole(UPGRADER_ROLE) {
        baseURI = baseURI_;
    }

    function allocate(address user_, uint256 quantity_) external onlyRole(UPGRADER_ROLE) {
        _mintTo(user_, quantity_);
    }

    // Non guarded
    function mint(uint256 quantity_) external {
        require(quantity_ > 0, "Minimum allowed 1 NFTs per address");
        require(tokensPerAddress[_msgSender()] + quantity_ <= LIMIT_PER_ADDRESS, "Maximum allowed 2 NFTs per address");
        require(purchaseToken.allowance(_msgSender(), address(this)) >= price * quantity_, "Token allowance is too low");
        require(purchaseToken.balanceOf(_msgSender()) >= price * quantity_, "Token balance is too low");
        require(totalMinted + quantity_ <= MINTABLE_SUPPLY, "Maximum supply of 1000 NFTs reached");

        purchaseToken.safeTransferFrom(_msgSender(), paymentReceiver, price * quantity_);

        _mintTo(_msgSender(), quantity_);
    }

    function rawFulfillRandomWords(uint256 requestId_, uint256[] memory randomWords_) external {
        require(_msgSender() == address(VRF_V2_WRAPPER), "Only VRF V2 wrapper can fulfill");

        uint256 tokenId = randomRequestIdToTokenId[requestId_];
        tokenIdToRandomWord[tokenId] = randomWords_[0];

        tokenIdToLandId[tokenId] = _removeUnassignedLandId(randomWords_[0] % unassignedLandIds.length);
    }

    /** PRIVATE SETTERS */
    function _mintTo(address user_, uint256 quantity_) private {
        for (uint256 index = 0; index < quantity_; index++) {
            totalMinted++;
            _safeMint(user_, totalMinted);
            _requestRandomness(totalMinted);
            tokensPerAddress[user_]++;
        }
    }

    function _removeUnassignedLandId(uint256 index_) private returns (uint256 landId) {
        require(index_ < unassignedLandIds.length, "Invalid index");
        landId = unassignedLandIds[index_];
        unassignedLandIds[index_] = unassignedLandIds[unassignedLandIds.length - 1];
        unassignedLandIds.pop();
    }

    function _requestRandomness(uint256 tokenId_) private {
        require(tokenIdToRandomWord[tokenId_] == 0, "Randomness was already persisted");
        uint32 callbackGasLimit = 300000;
        uint16 requestConfirmations = 5;
        uint32 numWords = 1;
        LINK.transferAndCall(
            address(VRF_V2_WRAPPER),
            VRF_V2_WRAPPER.calculateRequestPrice(callbackGasLimit),
            abi.encode(callbackGasLimit, requestConfirmations, numWords)
        );
        uint256 requestId = VRF_V2_WRAPPER.lastRequestId();
        randomRequestIdToTokenId[requestId] = tokenId_;
    }

    /** PRIVATE GETTERS */
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }
}
