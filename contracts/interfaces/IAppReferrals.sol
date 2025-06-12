// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.15;

interface IAppReferrals {
    // Events
    event ReferralCodeGenerated(address indexed referrer, bytes21 code);
    event ReferralUsed(address indexed referrer, address indexed referee, uint256 rewardAmount);
    event RewardsClaimed(address indexed referrer, uint256 amount);

    // Functions
    function initialize(address _bondDepository, address _staking, address _app, address _treasury, address _authority)
        external;

    function generateReferralCode() external returns (bytes21 code);
    function getReferralCode(address referrer) external view returns (bytes21 code);
    function getReferrals(address referrer) external view returns (address[] memory referrals);
    function claimRewards() external;
    function recordBondReferral(address referee, uint256 bondId, uint256 amount) external;
    function recordStakingReferral(address referee, uint256 amount) external;
    function getTotalRewards(address referrer) external view returns (uint256 rewards);
    function getReferralCount(address referrer) external view returns (uint256 count);
}
