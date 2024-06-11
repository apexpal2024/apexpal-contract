// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IAP.sol";
import "./interfaces/IBlast.sol";

contract Stake is Initializable, OwnableUpgradeable {
    IAP public AP;
    IBlast public constant BLAST = IBlast(0x4300000000000000000000000000000000000002);

    address public updater;
    uint256 public totalStakedAPXG;
    uint256[] public stakeAmounts;
    uint256[] public stakePeriods;

    struct Staking {
        uint256 amount;
        uint256 startTime;
        uint256 stakePeriod;
    }

    mapping(address => Staking) public stakings;

    event Staked(
        address indexed user,
        uint256 amount,
        uint256 startTime,
        uint256 stakePeriod
    );
    event Unstaked(address indexed user, uint256 amount);

    function initialize(address _AP, address _updater) public initializer {
        __Ownable_init(msg.sender);
        AP = IAP(_AP);
        updater = _updater;

        stakeAmounts.push(20000 ether);
        stakeAmounts.push(50000 ether);
        stakeAmounts.push(100000 ether);

        stakePeriods.push(7 days);
        stakePeriods.push(30 days);
        stakePeriods.push(60 days);
        stakePeriods.push(90 days);

        BLAST.configureClaimableGas();
    }

    function stake(uint256 _amountIndex, uint256 _periodIndex) external {
        address user = msg.sender;
        uint256 _amount = stakeAmounts[_amountIndex];
        uint256 _stakePeriod = stakePeriods[_periodIndex];

        require(stakings[user].amount == 0, "Stake: You have already staked");
        require(_amount > 0, "Stake: Invalid amount");
        require(_stakePeriod > 0, "Stake: Invalid period");

        require(
            AP.balanceOf(user) >= _amount,
            "Stake: Insufficient AP balance"
        );
        require(
            AP.allowance(user, address(this)) >= _amount,
            "Stake: Insufficient AP allowance"
        );
        SafeERC20.safeTransferFrom(AP, user, address(this), _amount);
        stakings[user] = Staking(_amount, block.timestamp, _stakePeriod);
        totalStakedAPXG += _amount;

        emit Staked(user, _amount, block.timestamp, _stakePeriod);
    }

    function checkStake(address _user) public view returns (Staking memory) {
        return stakings[_user];
    }

    function inStakePeriod(address _user) public view returns (bool) {
        Staking memory userStake = stakings[_user];
        if (userStake.amount == 0) {
            return false;
        }
        uint256 endTime = userStake.startTime + userStake.stakePeriod;
        return block.timestamp <= endTime;
    }

    function unstake() external {
        require(
            stakings[msg.sender].amount > 0,
            "Stake: You don't have a stake"
        );
        require(!inStakePeriod(msg.sender), "Stake: Unstake is not eligible");
        address user = msg.sender;
        uint256 amount = stakings[user].amount;
        delete stakings[user];
        SafeERC20.safeTransfer(AP, user, amount);
        totalStakedAPXG -= amount;
        emit Unstaked(user, amount);
    }


    function setUpdater(address _updater) external onlyOwner {
        updater = _updater;
    }

    function addStakeAmount(uint256 _amount) external returns (uint256) {
        require(
            msg.sender == updater || msg.sender == owner(),
            "Swap: You are not the updater"
        );
        stakeAmounts.push(_amount);
        return stakeAmounts.length - 1;
    }

    function addStakePeriod(uint256 _period) external returns (uint256) {
        require(
            msg.sender == updater || msg.sender == owner(),
            "Swap: You are not the updater"
        );
        stakePeriods.push(_period);
        return stakePeriods.length - 1;
    }


    function claimAllGas() external onlyOwner {
        BLAST.claimAllGas(address(this), msg.sender);
    }
}
