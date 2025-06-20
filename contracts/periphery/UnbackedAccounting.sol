// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import "../core/AppAccessControlled.sol";
import "../interfaces/IApp.sol";
import "../interfaces/IAppTreasury.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title UnbackedAccounting
/// @notice Contract that tracks RZR outflows and manages unbacked supply in the treasury
/// @dev This contract monitors RZR token movements and updates the treasury's unbacked supply accordingly
contract UnbackedAccounting is AppAccessControlled {
    using SafeERC20 for IERC20;

    /* ========== EVENTS ========== */

    event MonitoredContractAdded(address indexed contractAddress, uint256 unbackedSupply);
    event MonitoredContractUpdated(address indexed contractAddress, uint256 unbackedSupply);
    event MonitoredContractRemoved(address indexed contractAddress);
    event UnbackedSupplyUpdated(uint256 totalUnbackedSupply, uint256 totalOutflow, uint256 netUnbackedSupply);

    /* ========== STATE VARIABLES ========== */

    /// @notice The monitored contract
    struct MonitoredContract {
        /// @notice The address of the contract
        address contractAddress;
        /// @notice The unbacked supply of the contract
        uint256 unbackedSupply;
        /// @notice The outflow of the contract
        uint256 outflow;
    }

    /// @notice The monitored contracts
    MonitoredContract[] public monitoredContracts;

    /// @notice The RZR token contract
    IApp public immutable rzrToken;

    /// @notice The treasury contract
    IAppTreasury public immutable treasury;

    /// @notice The total outflow of all monitored contracts
    uint256 public totalOutflow;

    /// @notice The total unbacked supply of all monitored contracts
    uint256 public totalUnbackedSupply;

    /* ========== CONSTRUCTOR ========== */

    /// @notice Constructor for UnbackedAccounting
    /// @param _rzrToken The address of the RZR token contract
    /// @param _treasury The address of the treasury contract
    /// @param _authority The address of the authority contract
    constructor(address _rzrToken, address _treasury, address _authority) {
        require(_rzrToken != address(0), "Zero address: rzrToken");
        require(_treasury != address(0), "Zero address: treasury");
        require(_authority != address(0), "Zero address: authority");

        __AppAccessControlled_init(_authority);
        rzrToken = IApp(_rzrToken);
        treasury = IAppTreasury(_treasury);
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    /// @notice Add a contract to monitoring for RZR outflows
    /// @param _contractAddress The address of the contract to monitor
    /// @param _unbackedSupply The unbacked supply of the contract
    function addMonitoredContract(address _contractAddress, uint256 _unbackedSupply) external onlyGovernor {
        for (uint256 i = 0; i < monitoredContracts.length; i++) {
            if (monitoredContracts[i].contractAddress == _contractAddress) {
                monitoredContracts[i].unbackedSupply = _unbackedSupply;
                emit MonitoredContractUpdated(_contractAddress, _unbackedSupply);
                _update();
                return;
            }
        }

        monitoredContracts.push(
            MonitoredContract({contractAddress: _contractAddress, unbackedSupply: _unbackedSupply, outflow: 0})
        );

        emit MonitoredContractAdded(_contractAddress, _unbackedSupply);

        _update();
    }

    /// @notice Remove a contract from monitoring
    /// @param _contractAddress The address of the contract to remove
    function removeMonitoredContract(address _contractAddress) external onlyGovernor {
        // Remove from array
        for (uint256 i = 0; i < monitoredContracts.length; i++) {
            if (monitoredContracts[i].contractAddress == _contractAddress) {
                monitoredContracts[i] = monitoredContracts[monitoredContracts.length - 1];
                monitoredContracts.pop();
                break;
            }
        }

        emit MonitoredContractRemoved(_contractAddress);
        _update();
    }

    /// @notice Update the unbacked supply
    /// @dev This function is called by the executor to update the unbacked supply
    function update() external onlyExecutor {
        _update();
    }

    /// @notice Get the monitored contracts
    /// @return monitoredContracts The monitored contracts
    function getMonitoredContracts() external view returns (MonitoredContract[] memory) {
        return monitoredContracts;
    }

    /// @notice Get the net unbacked supply
    /// @return _netUnbackedSupply The net unbacked supply
    function getNetUnbackedSupply() external view returns (uint256 _netUnbackedSupply) {
        _netUnbackedSupply = totalUnbackedSupply - totalOutflow;
    }

    /// @notice Calculate the unbacked supply
    /// @return _totalOutflow The total outflow
    /// @return _totalUnbackedSupply The total unbacked supply
    /// @return _netUnbackedSupply The net unbacked supply
    function calculateUnbackedSupply()
        external
        view
        returns (uint256 _totalOutflow, uint256 _totalUnbackedSupply, uint256 _netUnbackedSupply)
    {
        return _preview();
    }

    /// @notice Update the unbacked supply
    /// @dev This function is called by the executor to update the unbacked supply
    function _update() internal {
        totalOutflow = 0;
        totalUnbackedSupply = 0;

        for (uint256 i = 0; i < monitoredContracts.length; i++) {
            MonitoredContract storage c = monitoredContracts[i];
            uint256 balance = rzrToken.balanceOf(c.contractAddress);
            // Outflow is the amount of tokens that have left the contract
            // If balance < unbackedSupply, then (unbackedSupply - balance) tokens have left
            // If balance >= unbackedSupply, then no tokens have left (outflow = 0)
            c.outflow = balance < c.unbackedSupply ? c.unbackedSupply - balance : 0;

            totalOutflow += c.outflow;
            totalUnbackedSupply += c.unbackedSupply;
        }

        uint256 _netUnbackedSupply = totalUnbackedSupply - totalOutflow;

        treasury.setUnbackedSupply(_netUnbackedSupply);
        emit UnbackedSupplyUpdated(totalUnbackedSupply, totalOutflow, _netUnbackedSupply);
    }

    /// @notice Preview the unbacked supply
    /// @dev This function is used to preview the unbacked supply
    /// @return _totalOutflow The total outflow
    /// @return _totalUnbackedSupply The total unbacked supply
    /// @return _netUnbackedSupply The net unbacked supply
    function _preview()
        internal
        view
        returns (uint256 _totalOutflow, uint256 _totalUnbackedSupply, uint256 _netUnbackedSupply)
    {
        for (uint256 i = 0; i < monitoredContracts.length; i++) {
            MonitoredContract memory c = monitoredContracts[i];
            uint256 balance = rzrToken.balanceOf(c.contractAddress);
            // Outflow is the amount of tokens that have left the contract
            uint256 outflow = balance < c.unbackedSupply ? c.unbackedSupply - balance : 0;

            _totalOutflow += outflow;
            _totalUnbackedSupply += c.unbackedSupply;
        }

        _netUnbackedSupply = _totalUnbackedSupply - _totalOutflow;
    }
}
