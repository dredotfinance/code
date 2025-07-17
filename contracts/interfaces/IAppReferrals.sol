// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAppReferrals {
    struct ClaimRewardsInput {
        address user;
        uint256 amount;
        bytes32[] proofs;
    }

    // Events
    event ReferralCodeRegistered(address indexed referrer, bytes8 code);
    event ReferralRegistered(address indexed referred, address indexed referrer, bytes8 code);
    event RewardsClaimed(address indexed user, uint256 amount, bytes32 root);
    event ReferralStaked(address indexed user, uint256 amount, uint256 declaredValue, bytes8 referralCode);
    event ReferralBondBought(address indexed user, uint256 payout, bytes8 referralCode);
    event ReferralStakedIntoLST(address indexed user, uint256 amount, bytes8 referralCode);
    event MerkleServerSet(address indexed merkleServer);
    event EnableWhitelistingSet(bool indexed enableWhitelisting);
    event MerkleRootSet(bytes32 indexed merkleRoot);
    event Whitelisted(address indexed user);

    // Functions
    /// @notice Initializes the contract
    /// @param _bondDepository The address of the bond depository
    /// @param _staking The address of the staking contract
    /// @param _app The address of the app
    /// @param _treasury The address of the treasury
    /// @param _staking4626 The address of the staking4626 contract
    /// @param _authority The address of the authority
    function initialize(
        address _bondDepository,
        address _staking,
        address _app,
        address _treasury,
        address _staking4626,
        address _authority
    ) external;

    /// @notice Gets the referrer code for a user
    /// @param _user The user to get the referrer code for
    /// @return referrerCode The referrer code for the user
    function referrerCodes(address _user) external view returns (bytes8 referrerCode);

    /// @notice Sets the merkle server
    /// @param _merkleServer The merkle server address
    function setMerkleServer(address _merkleServer) external;

    /// @notice Sets the merkle root for the current week
    /// @param _merkleRoot The merkle root for the week
    function setMerkleRoot(bytes32 _merkleRoot) external;

    /// @notice Whitelists an address
    /// @param _user The address to whitelist
    function whitelist(address _user) external;

    /// @notice Sets the enable whitelisting
    /// @param _enableWhitelisting The enable whitelisting
    function setEnableWhitelisting(bool _enableWhitelisting) external;

    /// @notice Claims rewards using a merkle proof
    /// @param inputs The inputs for the rewards to claim
    /// @dev The proofs are the two parts of the merkle proof
    function claimRewards(ClaimRewardsInput[] calldata inputs) external;

    /// @notice Registers a referral code for the caller
    function registerReferralCode(bytes8 code) external;

    /// @notice Registers a referral code for the given referrer
    /// @param _code The referral code to register
    /// @param _referrer The referrer to register the referral code for
    function registerReferralCodeFor(bytes8 _code, address _referrer) external;

    /// @notice Gets all referrals for a referrer
    /// @param referrer The referrer to get referrals for
    /// @return referrals Array of addresses that were referred
    function getReferrals(address referrer) external view returns (address[] memory referrals);

    /// @notice Stakes RZR tokens with a referral code
    /// @param amount The amount of RZR tokens to stake
    /// @param declaredValue The declared value of the stake
    /// @param _referralCode The referral code to use
    /// @param _to The address to stake for
    /// @return tokenId_ The ID of the created stake position NFT
    /// @return taxPaid_ The amount of tax paid
    function stakeWithReferral(uint256 amount, uint256 declaredValue, bytes8 _referralCode, address _to)
        external
        returns (uint256 tokenId_, uint256 taxPaid_);

    /// @notice Stakes RZR tokens with a referral code into the LST
    /// @param amount The amount of RZR tokens to stake
    /// @param _referralCode The referral code to use
    /// @param _to The address to stake for
    /// @return minted The amount of tokens minted
    function stakeIntoLSTWithReferral(uint256 amount, bytes8 _referralCode, address _to)
        external
        returns (uint256 minted);

    /// @notice Buys a bond with a referral code
    /// @param _id The ID of the bond to buy
    /// @param _amount The amount of quote tokens to pay
    /// @param _maxPrice The maximum price to pay
    /// @param _minPayout The minimum payout to receive
    /// @param _referralCode The referral code to use
    /// @param _to The address to buy the bond for
    /// @return payout_ The amount of RZR tokens received
    /// @return tokenId_ The ID of the created bond position NFT
    function bondWithReferral(
        uint256 _id,
        uint256 _amount,
        uint256 _maxPrice,
        uint256 _minPayout,
        bytes8 _referralCode,
        address _to
    ) external returns (uint256 payout_, uint256 tokenId_);
}
