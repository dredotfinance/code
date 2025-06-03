// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "../interfaces/IAggregatorV3.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TwapOracle
 * @notice This contract implements a Time-Weighted Average Price (TWAP) oracle
 * @dev Uses a circular buffer to store price _observations and calculate TWAP
 */
contract TwapOracle is AggregatorV3Interface, Ownable {
    struct Observation {
        uint256 timestamp;
        int256 price;
    }

    AggregatorV3Interface public immutable oracle;
    uint256 public   windowSize;
    uint256 public   MAX_OBSERVATIONS = 100;
    uint256 public minUpdateInterval;

    Observation[] public _observations;
    uint256 public currentIndex;
    uint256 public lastUpdateTime;

    event ObservationAdded(uint256 timestamp, int256 price);
    event WindowSizeUpdated(uint256 newWindowSize);

    address public updater;

    constructor(
        AggregatorV3Interface _oracle,
        uint256 _minUpdateInterval,
        uint256 _windowSize,
        address _updater
    ) Ownable(msg.sender) {
        require(address(_oracle) != address(0), "Invalid oracle address");
        require(_windowSize > 0, "Window size must be > 0");

        oracle = _oracle;
        windowSize = _windowSize;
        minUpdateInterval = _minUpdateInterval;
        updater = _updater;

        // Initialize with one observation
        _observations.push(Observation({
            timestamp: block.timestamp,
            price: _oracle.latestAnswer()
        }));
    }

    /**
     * @notice Updates the price observation
     * @dev Can be called by anyone to update the price
     */
    function update() public {
        require(msg.sender == updater, "Only updater can update");
        require(block.timestamp >= lastUpdateTime + minUpdateInterval, "Too early to update");

        int256 price = oracle.latestAnswer();
        require(price > 0, "Invalid price");

        if (_observations.length < MAX_OBSERVATIONS) {
            _observations.push(Observation({
                timestamp: block.timestamp,
                price: price
            }));
        } else {
            currentIndex = (currentIndex + 1) % MAX_OBSERVATIONS;
            _observations[currentIndex] = Observation({
                timestamp: block.timestamp,
                price: price
            });
        }

        lastUpdateTime = block.timestamp;
        emit ObservationAdded(block.timestamp, price);
    }

    function observations(uint256 _index) public view returns (Observation memory) {
        return _observations[_index];
    }

    /**
     * @notice Calculates the TWAP over the window size
     * @return twap The time-weighted average price
     */
    function getTwap() public view returns (int256 twap) {
        require(_observations.length > 0, "No _observations");

        uint256 endTime = block.timestamp;
        uint256 startTime = endTime - windowSize;

        uint256 totalTime = 0;
        int256 weightedSum = 0;

        for (uint256 i = 0; i < _observations.length; i++) {
            Observation memory obs = _observations[i];

            if (obs.timestamp >= startTime) {
                uint256 timeWeight = obs.timestamp - startTime;
                weightedSum += obs.price * int256(timeWeight);
                totalTime += timeWeight;
            }
        }

        require(totalTime > 0, "No _observations in window");
        twap = weightedSum / int256(totalTime);
    }

    function decimals() external view override returns (uint8) {
        return oracle.decimals();
    }

    function description() external view override returns (string memory) {
        return string.concat("TWAP Oracle for ", oracle.description());
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function getRoundData(uint80)
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return latestRoundData();
    }

    function latestRoundData()
        public
        view
        override
        returns (uint80  , int256  , uint256  , uint256  , uint80  )
    {
        (uint80 roundId, , uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = oracle.latestRoundData();
        return (roundId, getTwap(), startedAt, updatedAt, answeredInRound);
    }

    function latestAnswer() external view override returns (int256) {
        return getTwap();
    }
}
