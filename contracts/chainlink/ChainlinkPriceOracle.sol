// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract ChainlinkPriceOracle {
    
    // Events
    event PriceRetrieved(
        uint80 roundID,
        int price,
        uint startedAt,
        uint timeStamp,
        uint80 answeredInRound
    );

    // Variables
    AggregatorV3Interface internal priceFeed;

    constructor() {
        // ETH-USD
        priceFeed = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
    }

    function getLatestPrice() public returns (int) {
        (
            uint80 roundID,
            int price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();

        emit PriceRetrieved(
            roundID,
            price,
            startedAt,
            timeStamp,
            answeredInRound
        );

        // for ETH / USD price is scaled up by 10 ** 8
        return price / 1e18;
    }

}

interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int answer,
            uint startedAt,
            uint updatedAt,
            uint80 answeredInRound
        );
}