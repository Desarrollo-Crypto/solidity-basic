// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakingRewards is Ownable {

    /* ========== STATE VARIABLES ========== */

    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardsToken;

    uint public totalSupply; // Total staked
    mapping(address => uint) public balances; // User address => staked amount

    uint public duration; // Duration of rewards to be paid out (in seconds)
    uint public finishAt; // Timestamp of when the rewards finish
    uint public updatedAt; // Minimum of last updated time and reward finish time
    uint public rewardRate; // Reward to be paid out per second;
    uint public rewardPerTokenStored; // Sum of (reward rate * duration * 1e18 / total supply)
    mapping(address => uint) public userRewardPerTokenPaid; // User address => rewardPerTokenStored
    mapping(address => uint) public rewards; // User address => rewards to be claimed

    /* ========== CONSTRUCTOR ========== */

    constructor(address _stakingToken, address _rewardsToken) {
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);
    }

    /* ========== VIEW ========== */

    function earned(address _account) public view returns (uint) {
        return
            ((balances[_account] *
                (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18) +
            rewards[_account];
    }

    function rewardPerToken() public view returns (uint) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }

        return 
            rewardPerTokenStored +
            (rewardRate * (lastTimeRewardApplicable() - updatedAt) * 1e18) /
            totalSupply;
    }

    function lastTimeRewardApplicable() public view returns (uint) {
        return _min(finishAt, block.timestamp);
    }
    
    /* ========== PUBLIC ========== */

    function stake(uint _amount) external updateReward(msg.sender) {
        require(_amount > 0, "amount = 0");

        stakingToken.transferFrom(msg.sender, address(this), _amount);

        balances[msg.sender] += _amount;
        totalSupply += _amount;

        emit Staked(msg.sender, _amount);
    }

    function withdraw(uint _amount) external updateReward(msg.sender) {
        require(_amount > 0, "amount = 0");

        balances[msg.sender] -= _amount;
        totalSupply -= _amount;

        stakingToken.transfer(msg.sender, _amount);

        emit Withdrawn(msg.sender, _amount);
    }

    function getReward() external updateReward(msg.sender) {
        uint reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.transfer(msg.sender, reward);
        }
    }

    function setRewardsDuration(uint _duration) external onlyOwner {
        require(finishAt < block.timestamp, "reward duration not finished");
        duration = _duration;
    }

    function notifyRewardAmount(uint _amount)
        external
        onlyOwner
        updateReward(address(0))
    {
        if (block.timestamp >= finishAt) {
            rewardRate = _amount / duration;
        } else {
            uint remainingRewards = (finishAt - block.timestamp) * rewardRate;
            rewardRate = (_amount + remainingRewards) / duration;
        }

        require(rewardRate > 0, "reward rate = 0");
        require(
            rewardRate * duration <= rewardsToken.balanceOf(address(this)),
            "reward amount > balance"
        );

        finishAt = block.timestamp + duration;
        updatedAt = block.timestamp;
    }

    /* ========== PRIVATE ========== */

    function _min(uint x, uint y) private pure returns (uint) {
        return x <= y ? x : y;
    }

    /* ========== MODIFIERS ========== */

    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();

        if (_account != address(0)) {
            rewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        }

        _;
    }

    /* ========== EVENTS ========== */

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
}