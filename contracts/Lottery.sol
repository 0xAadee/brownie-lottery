// SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Lottery is VRFConsumerBase, Ownable {
    address payable[] public players;
    address payable public recentWinner;
    uint256 public randomness;
    uint256 public usdEntryFee;
    AggregatorV3Interface internal ethUsdPriceFeed;

    enum LotteryState {
        OPEN,
        CLOSED,
        CALCULATING_WINNER
    }

    // OPEN = 0
    // CLOSED = 1
    // CALCULATING_WINNER = 2

    LotteryState public lotteryState;
    uint256 public fee;
    bytes32 public keyHash;
    event RequestedRandomness(bytes32 requestId);

    constructor(
        address _priceFeedAddress,
        address _vrfCoordinator,
        address _linkToken,
        uint256 _fee,
        bytes32 _keyHash
    ) public VRFConsumerBase(_vrfCoordinator, _linkToken) {
        usdEntryFee = 50 * (10**18);
        ethUsdPriceFeed = AggregatorV3Interface(_priceFeedAddress);
        lotteryState = LotteryState.CLOSED;
        fee = _fee;
        keyHash = _keyHash;
    }

    function enterLottery() public payable {
        // $50 minimum
        require(
            lotteryState == LotteryState.OPEN,
            "Lottery has not started yet"
        );
        require(msg.value >= getEntranceFee(), "Not enough ETH!");
        players.push(msg.sender);
    }

    function getEntranceFee() public view returns (uint256) {
        (, int256 price, , , ) = ethUsdPriceFeed.latestRoundData();
        uint256 adjustedPrice = uint256(price) * 10**10;
        uint256 costToEnter = (usdEntryFee * 10**18) / adjustedPrice;
        return costToEnter;
    }

    function startLottery() public onlyOwner {
        require(
            lotteryState == LotteryState.CLOSED,
            "A Lottery is already open"
        );
        lotteryState = LotteryState.OPEN;
    }

    function endLottery() public onlyOwner {
        lotteryState = LotteryState.CALCULATING_WINNER;
        bytes32 requestId = requestRandomness(keyHash, fee);
        emit RequestedRandomness(requestId);
    }

    function fulfillRandomness(bytes32 _requestId, uint256 _randomness)
        internal
        override
    {
        require(
            lotteryState == LotteryState.CALCULATING_WINNER,
            "You aren't there yet!"
        );
        require(_randomness > 0, "Random Not Found");
        uint256 winnerIndex = _randomness % players.length;
        recentWinner = players[winnerIndex];
        recentWinner.transfer(address(this).balance);
    
        // Reset
        players = new address payable[](0);
        lotteryState = LotteryState.CLOSED;
        randomness = _randomness;
    }
}
