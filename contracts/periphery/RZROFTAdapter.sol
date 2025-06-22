// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import "../core/AppAccessControlled.sol";
import "@layerzerolabs/oft-evm/contracts/OFTAdapter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RZROFTAdapter is OFTAdapter, AppAccessControlled {
    constructor(address _oft, address _lzEndpoint, address _authority)
        OFTAdapter(_oft, _lzEndpoint, msg.sender)
        Ownable(msg.sender)
    {
        __AppAccessControlled_init(_authority);
        _transferOwnership(address(0));
    }

    function _checkOwner() internal view virtual override {
        if (!authority.isGovernor(_msgSender())) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    function recall(address _token) external onlyGovernor {
        IERC20(_token).transfer(msg.sender, IERC20(_token).balanceOf(address(this)));
    }
}
