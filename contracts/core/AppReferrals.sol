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

    bytes32 public merkleRoot;

    // Track claimed rewards
    mapping(address user => uint256 claimed) public claimedRewards; // user => claimed

    // Referral tracking
    mapping(address user => address referrer) public trackedReferrals;
    mapping(address referrer => EnumerableSet.AddressSet referrals) private _referrals;
    mapping(address user => bytes8 code) public referrerCodes;
    mapping(bytes8 code => address user) public referralCodes;

    address public merkleServer;
    uint256 public totalClaimed;

    /// @inheritdoc IAppReferrals
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

    /// @inheritdoc IAppReferrals
    function setMerkleServer(address _merkleServer) external onlyGovernor {
        merkleServer = _merkleServer;
    }

    /// @inheritdoc IAppReferrals
    function setMerkleRoot(bytes32 _merkleRoot) external {
        require(msg.sender == merkleServer, "Only merkle server can set merkle root");
        merkleRoot = _merkleRoot;
    }

    /// @inheritdoc IAppReferrals
    function claimRewards(ClaimRewardsInput[] calldata inputs) external {
        for (uint256 i = 0; i < inputs.length; i++) {
            _claimRewards(inputs[i]);
        }
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

    /// @notice Gets the total number of referrals made by a referrer
    /// @param _referrer The referrer to get the total number of referrals for
    /// @return The total number of referrals made by the referrer
    function totalReferralsMade(address _referrer) external view returns (uint256) {
        return _referrals[_referrer].length();
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

        emit ReferralBondBought(_to, payout_, _referralCode);
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
        // Create the leaf node
        bytes32 leaf = keccak256(abi.encodePacked(input.user, input.amount));

        // Verify the proof
        require(input.proofs.verify(merkleRoot, leaf), "Invalid proof");

        // Check if already claimed
        uint256 claimable = input.amount - claimedRewards[input.user];
        require(claimable > 0, "No rewards to claim");
        claimedRewards[input.user] += claimable;
        totalClaimed += claimable;

        // Transfer rewards
        app.transfer(input.user, claimable);

        emit RewardsClaimed(input.user, input.amount, merkleRoot);
    }
}
