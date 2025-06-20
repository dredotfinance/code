// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import "./AppAccessControlled.sol";
import "../interfaces/IAppOracle.sol";
import "../interfaces/IApp.sol";
import "../interfaces/IAppTreasury.sol";
import "../interfaces/IAppBondDepository.sol";
import "../interfaces/IAppStaking.sol";
import "../interfaces/IAppReferrals.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/// @title AppReferrals
/// @notice This contract is used to track referrals and rewards
/// @dev Reward calculations are done off-chain in future yields
contract AppReferrals is AppAccessControlled, ReentrancyGuardUpgradeable, IAppReferrals {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using MerkleProof for bytes32[];

    // State variables
    IAppBondDepository public bondDepository;
    IAppStaking public staking;
    IApp public app;
    IAppTreasury public treasury;

    bytes32[] public merkleRoots;

    // Track claimed rewards
    mapping(bytes32 => mapping(bytes32 => bool)) public claimedRewards; // root => leaf => claimed
    mapping(bytes32 => MerkleRootInfo) public merkleRootInfo; // root => root info

    // Referral tracking
    mapping(address referred => address referrer) public trackedReferrals;
    mapping(address => EnumerableSet.AddressSet) private _referrals;
    mapping(address => bytes8) public referrerCodes;
    mapping(bytes8 => address) public referralCodes;

    address public odos;
    address public merkleServer;

    /// @inheritdoc IAppReferrals
    function initialize(
        address _bondDepository,
        address _staking,
        address _app,
        address _treasury,
        address _authority,
        address _odos
    ) external initializer {
        __AppAccessControlled_init(_authority);
        __ReentrancyGuard_init();

        bondDepository = IAppBondDepository(_bondDepository);
        staking = IAppStaking(_staking);
        app = IApp(_app);
        treasury = IAppTreasury(_treasury);
        odos = _odos;
        app.approve(address(staking), type(uint256).max);
    }

    /// @inheritdoc IAppReferrals
    function setMerkleServer(address _merkleServer) external onlyGovernor {
        merkleServer = _merkleServer;
    }

    /// @inheritdoc IAppReferrals
    function addMerkleRoot(bytes32 _merkleRoot, uint256 amount) external {
        require(msg.sender == merkleServer, "Only merkle server can add merkle roots");

        require(merkleRootInfo[_merkleRoot].root == bytes32(0), "Merkle root already set");

        app.transferFrom(msg.sender, address(this), amount);
        merkleRootInfo[_merkleRoot] = MerkleRootInfo({root: _merkleRoot, amount: amount, claimed: 0});
        merkleRoots.push(_merkleRoot);
    }

    /// @inheritdoc IAppReferrals
    function claimRewards(ClaimRewardsInput[] calldata inputs) external {
        for (uint256 i = 0; i < inputs.length; i++) {
            _claimRewards(inputs[i]);
        }
    }

    /// @inheritdoc IAppReferrals
    function getMerkleRootCount() external view returns (uint256) {
        return merkleRoots.length;
    }

    /// @inheritdoc IAppReferrals
    function getMerkleRootInfo(bytes32 root) external view returns (uint256 amount, uint256 claimed) {
        MerkleRootInfo storage info = merkleRootInfo[root];
        return (info.amount, info.claimed);
    }

    /// @inheritdoc IAppReferrals
    function registerReferralCode(bytes8 _code) external {
        require(referralCodes[_code] == address(0), "Code already exists");
        require(referrerCodes[msg.sender] == bytes8(0), "Referral code already registered");
        require(_code != bytes8(0), "Invalid code");

        referralCodes[_code] = msg.sender;
        referrerCodes[msg.sender] = _code;

        emit ReferralCodeRegistered(msg.sender, _code);
    }

    /// @inheritdoc IAppReferrals
    function getReferrals(address _referrer) external view returns (address[] memory referrals) {
        EnumerableSet.AddressSet storage refs = _referrals[_referrer];
        referrals = new address[](refs.length());
        for (uint256 i = 0; i < refs.length(); i++) {
            referrals[i] = refs.at(i);
        }
    }

    /// @inheritdoc IAppReferrals
    function stakeWithReferral(uint256 amount, uint256 declaredValue, bytes8 _referralCode, address _to)
        external
        nonReentrant
        returns (uint256 tokenId, uint256 taxPaid)
    {
        app.transferFrom(msg.sender, address(this), amount);

        // pay out any referral rewards if a referral code was set
        _registerReferral(_referralCode, _to);

        // stake on behalf of the referrer
        (tokenId, taxPaid) = staking.createPosition(_to, amount, declaredValue, 0);

        emit ReferralStaked(_to, amount, declaredValue, _referralCode);
    }

    /// @inheritdoc IAppReferrals
    function bondWithReferral(
        uint256 _id,
        uint256 _amount,
        uint256 _maxPrice,
        uint256 _minPayout,
        bytes8 _referralCode,
        address _to
    ) external nonReentrant returns (uint256 payout_, uint256 tokenId_) {
        IAppBondDepository.Bond memory bond = bondDepository.getBond(_id);
        IERC20 token = bond.quoteToken;

        // register referral if not already registered for tracking purposes only
        _registerReferral(_referralCode, _to);

        // buy bond on behalf of the referrer
        token.transferFrom(msg.sender, address(this), _amount);
        token.approve(address(bondDepository), _amount);
        (payout_, tokenId_) = bondDepository.deposit(_id, _amount, _maxPrice, _minPayout, _to);

        emit ReferralBondBought(_to, _id, _amount, _maxPrice, _minPayout, _referralCode);
    }

    /// @dev Registers a referral for the given user
    /// @param _referralCode The referral code to use
    /// @param _user The user to register the referral for
    function _registerReferral(bytes8 _referralCode, address _user) internal {
        // if the user is already tracked by someone, we skip
        if (trackedReferrals[_user] != address(0)) return;

        // track the referral
        address _referrer = referralCodes[_referralCode];
        if (_referrer == address(0)) return;
        trackedReferrals[_user] = _referrer;

        if (!_referrals[_referrer].contains(_user)) {
            _referrals[_referrer].add(_user);
        }

        emit ReferralRegistered(_user, _referrer, _referralCode);
    }

    /// @dev Claims rewards for the given input
    /// @param input The input to claim rewards for
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
