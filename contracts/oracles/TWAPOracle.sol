// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IOracle.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TwapOracle
 * @notice This contract implements a Time-Weighted Average Price (TWAP) oracle
 * @dev Uses a circular buffer to store price _observations and calculate TWAP
 */
contract TwapOracle is IOracle, Ownable {
    struct Observation {
        uint256 timestamp;
        uint256 price;
    }

    IOracle public oracle;
    uint256 public windowSize;
    uint256 public immutable MAX_OBSERVATIONS = 10;
    uint256 public minUpdateInterval;

    Observation[] public _observations;
    uint256 public currentIndex;
    uint256 public lastUpdateTime;

    event ObservationAdded(uint256 timestamp, uint256 price);
    event UpdaterUpdated(address updater);

    address public updater;

    /**
     * @notice Constructor
     * @param _oracle The oracle to use
     * @param _minUpdateInterval The minimum update interval
     * @param _windowSize The window size
     * @param _updater The updater
     */
    constructor(IOracle _oracle, uint256 _minUpdateInterval, uint256 _windowSize, address _updater)
        Ownable(msg.sender)
    {
        require(address(_oracle) != address(0), "Invalid oracle address");
        require(_windowSize > 0, "Window size must be > 0");

        oracle = _oracle;
        windowSize = _windowSize;
        minUpdateInterval = _minUpdateInterval;
        updater = _updater;

        _observations.push(Observation({timestamp: block.timestamp, price: _oracle.getPrice()}));
        emit ObservationAdded(block.timestamp, _oracle.getPrice());
        emit UpdaterUpdated(_updater);
    }

    /**
     * @notice Sets the updater
     * @param _updater The new updater
     */
    function setUpdater(address _updater) external onlyOwner {
        updater = _updater;
        emit UpdaterUpdated(_updater);
    }

    /**
     * @notice Updates the price observation
     * @dev Can be called by anyone to update the price
     */
    function update() public {
        require(msg.sender == updater, "Only updater can update");
        require(block.timestamp >= lastUpdateTime + minUpdateInterval, "Too early to update");

        uint256 price = oracle.getPrice();
        require(price > 0, "Invalid price");

        if (_observations.length < MAX_OBSERVATIONS) {
            _observations.push(Observation({timestamp: block.timestamp, price: price}));
        } else {
            currentIndex = (currentIndex + 1) % MAX_OBSERVATIONS;
            _observations[currentIndex] = Observation({timestamp: block.timestamp, price: price});
        }

        lastUpdateTime = block.timestamp;
        emit ObservationAdded(block.timestamp, price);
    }

    /**
     * @notice Returns an observation
     * @param _index The index of the observation
     * @return obs The observation
     */
    function observations(uint256 _index) public view returns (Observation memory) {
        return _observations[_index];
    }

    /**
     * @notice Calculates the TWAP over the window size
     * @return twap The time-weighted average price
     */
    function getTwap() public view returns (uint256 twap) {
        require(_observations.length > 0, "No _observations");

        uint256 endTime = block.timestamp;
        uint256 startTime = endTime - windowSize;

        uint256 totalTime = 0;
        uint256 weightedSum = 0;

        for (uint256 i = 0; i < _observations.length; i++) {
            Observation memory obs = _observations[i];

            if (obs.timestamp >= startTime) {
                uint256 timeWeight = obs.timestamp - startTime;
                weightedSum += obs.price * timeWeight;
                totalTime += timeWeight;
            }
        }

        require(totalTime > 0, "No _observations in window");
        twap = weightedSum / totalTime;
    }

    /**
     * @notice Returns the TWAP price
     * @return twap The time-weighted average price
     */
    function getPrice() external view override returns (uint256) {
        return getTwap();
    }
}
