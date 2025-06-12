// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.15;

import "./AppAccessControlled.sol";
import "./interfaces/IAppOracle.sol";
import "./interfaces/IApp.sol";
import "./interfaces/IAppTreasury.sol";
import "./interfaces/IAppBondDepository.sol";
import "./interfaces/IAppStaking.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/// @title AppReferrals
/// @notice This contract is used to track referrals and rewards
/// @dev Reward calculations are done off-chain in future yields
contract AppReferrals is AppAccessControlled, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using MerkleProof for bytes32[];

    // State variables
    IAppBondDepository public bondDepository;
    IAppStaking public staking;
    IApp public app;
    IAppTreasury public treasury;

    // Merkle roots for rewards
    struct MerkleRootInfo {
        bytes32 root;
        uint256 amount;
        uint256 claimed;
    }

    // Events
    event ReferralCodeRegistered(address indexed referrer, bytes8 code);
    event ReferralRegistered(address indexed referred, address indexed referrer, bytes8 code);
    event RewardsClaimed(address indexed user, uint256 amount, bytes32 root);
    event ReferralStaked(address indexed user, uint256 amount, uint256 declaredValue, bytes8 referralCode);
    event ReferralBondBought(
        address indexed user, uint256 id, uint256 amount, uint256 maxPrice, uint256 minPayout, bytes8 referralCode
    );

    struct ClaimRewardsInput {
        bytes32 root;
        address user;
        uint256 amount;
        bytes32[] proofs;
    }

    bytes32[] public merkleRoots;

    // Track claimed rewards
    mapping(bytes32 => mapping(bytes32 => bool)) public claimedRewards; // root => leaf => claimed
    mapping(bytes32 => MerkleRootInfo) public merkleRootInfo; // root => root info

    // Referral tracking
    mapping(address referred => address referrer) public trackedReferrals;
    mapping(address => EnumerableSet.AddressSet) private _referrals;
    mapping(address => bytes8) public referrerCodes;
    mapping(bytes8 => address) public referralCodes;

    address public merkleServer;

    function initialize(address _bondDepository, address _staking, address _app, address _treasury, address _authority)
        external
        initializer
    {
        __AppAccessControlled_init(_authority);
        __ReentrancyGuard_init();

        bondDepository = IAppBondDepository(_bondDepository);
        staking = IAppStaking(_staking);
        app = IApp(_app);
        treasury = IAppTreasury(_treasury);

        app.approve(address(staking), type(uint256).max);
    }

    /// @notice Sets the merkle server
    /// @param _merkleServer The merkle server address
    function setMerkleServer(address _merkleServer) external onlyGovernor {
        merkleServer = _merkleServer;
    }

    /// @notice Adds a new merkle root for the current week
    /// @param _merkleRoot The merkle root for the week
    /// @param amount The amount of rewards to claim
    function addMerkleRoot(bytes32 _merkleRoot, uint256 amount) external {
        require(msg.sender == merkleServer, "Only merkle server can add merkle roots");

        require(merkleRootInfo[_merkleRoot].root == bytes32(0), "Merkle root already set");

        app.transferFrom(msg.sender, address(this), amount);
        merkleRootInfo[_merkleRoot] = MerkleRootInfo({root: _merkleRoot, amount: amount, claimed: 0});
        merkleRoots.push(_merkleRoot);
    }

    /// @notice Claims rewards using a merkle proof
    /// @param inputs The inputs for the rewards to claim
    /// @dev The proofs are the two parts of the merkle proof
    function claimRewards(ClaimRewardsInput[] calldata inputs) external {
        for (uint256 i = 0; i < inputs.length; i++) {
            _claimRewards(inputs[i]);
        }
    }

    /// @notice Gets the number of merkle roots
    /// @return The number of merkle roots
    function getMerkleRootCount() external view returns (uint256) {
        return merkleRoots.length;
    }

    /// @notice Gets the merkle root info
    /// @param root The merkle root
    /// @return amount The amount of rewards
    /// @return claimed The amount of rewards claimed
    function getMerkleRootInfo(bytes32 root) external view returns (uint256 amount, uint256 claimed) {
        MerkleRootInfo storage info = merkleRootInfo[root];
        return (info.amount, info.claimed);
    }

    /// @notice Registers a referral code for the caller
    function registerReferralCode(bytes8 code) external {
        require(referralCodes[code] == address(0), "Code already exists");
        require(referrerCodes[msg.sender] == bytes8(0), "Referral code already registered");
        require(code != bytes8(0), "Invalid code");

        referralCodes[code] = msg.sender;
        referrerCodes[msg.sender] = code;

        emit ReferralCodeRegistered(msg.sender, code);
    }

    /// @notice Gets all referrals for a referrer
    /// @param referrer The referrer to get referrals for
    /// @return referrals Array of addresses that were referred
    function getReferrals(address referrer) external view returns (address[] memory referrals) {
        EnumerableSet.AddressSet storage refs = _referrals[referrer];
        referrals = new address[](refs.length());
        for (uint256 i = 0; i < refs.length(); i++) {
            referrals[i] = refs.at(i);
        }
    }

    /// @notice Stakes RZR tokens with a referral code
    /// @param amount The amount of RZR tokens to stake
    /// @param declaredValue The declared value of the stake
    /// @param referralCode The referral code to use
    function stakeWithReferral(uint256 amount, uint256 declaredValue, bytes8 referralCode) external nonReentrant {
        app.transferFrom(msg.sender, address(this), amount);

        // pay out any referral rewards if a referral code was set
        _registerReferral(referralCode, msg.sender);

        // stake on behalf of the referrer
        staking.createPosition(msg.sender, amount, declaredValue, 0);

        emit ReferralStaked(msg.sender, amount, declaredValue, referralCode);
    }

    /// @notice Buys a bond with a referral code
    /// @param _id The ID of the bond to buy
    /// @param _amount The amount of quote tokens to pay
    /// @param _maxPrice The maximum price to pay
    /// @param _minPayout The minimum payout to receive
    /// @param referralCode The referral code to use
    function bondWithReferral(uint256 _id, uint256 _amount, uint256 _maxPrice, uint256 _minPayout, bytes8 referralCode)
        external
        nonReentrant
    {
        IAppBondDepository.Bond memory bond = bondDepository.getBond(_id);
        IERC20 token = bond.quoteToken;

        // register referral if not already registered for tracking purposes only
        _registerReferral(referralCode, msg.sender);

        // buy bond on behalf of the referrer
        token.transferFrom(msg.sender, address(this), _amount);
        token.approve(address(bondDepository), _amount);
        bondDepository.deposit(_id, _amount, _maxPrice, _minPayout, msg.sender);

        emit ReferralBondBought(msg.sender, _id, _amount, _maxPrice, _minPayout, referralCode);
    }

    function _registerReferral(bytes8 referralCode, address user) internal {
        // user is already tracked by someone; so we skip
        if (trackedReferrals[user] != address(0)) return;

        // track the referral
        address referrer = referralCodes[referralCode];
        if (referrer == address(0)) return;
        trackedReferrals[user] = referrer;

        if (!_referrals[referrer].contains(user)) {
            _referrals[referrer].add(user);
        }

        emit ReferralRegistered(user, referrer, referralCode);
    }

    function _claimRewards(ClaimRewardsInput calldata input) internal nonReentrant {
        MerkleRootInfo storage rootInfo = merkleRootInfo[input.root];
        require(rootInfo.root != bytes32(0), "Merkle root not set");

        // Create the leaf node
        bytes32 leaf = keccak256(abi.encodePacked(input.user, input.amount));

        // Verify the proof
        require(input.proofs.verify(rootInfo.root, leaf), "Invalid proof");

        // Check if already claimed
        require(!claimedRewards[input.root][leaf], "Rewards already claimed");
        claimedRewards[input.root][leaf] = true;

        // invariant check
        require(rootInfo.claimed + input.amount <= rootInfo.amount, "Not enough rewards to claim");
        rootInfo.claimed += input.amount;

        // Transfer rewards
        app.transfer(input.user, input.amount);

        emit RewardsClaimed(input.user, input.amount, input.root);
    }
}
