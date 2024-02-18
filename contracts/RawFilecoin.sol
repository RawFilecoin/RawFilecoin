// SPDX-License-Identifier: MIT
// RawFilecoin Contract - Reward Filecoin Miners based on storage capacity committed to the network only

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import "./Utils/FilecoinAPI.sol";

/// @dev A simple implementation of RawFilecoin building on FEVM
/// @dev Anyone can burn its own RFIL token
contract RawFilecoin is ERC20Burnable {
    // Events to log binding and unbinding of minters for miners
    event Bind(
        uint64 indexed minerId,
        address indexed minter,
        address indexed sender
    );
    event Unbind(
        uint64 indexed minerId,
        address indexed sender
    );
    event MinerMint(
        uint64 indexed minerId,
        address indexed minter,
        uint amount
    );

    // State variables
    // Mapping to track previous successful reward claim block height of miners
    mapping(uint64 => uint) private _prevHeight;
    // Mapping to associate miners with minters
    mapping(uint64 => address) private _minerBindsMap;
    // Mapping to store the released tokens at specific block heights
    mapping(uint => uint) private _released;
    
    uint private _startHeight;     // The block height when the contract was deployed
    uint private _adjustFactor;    // The adjustment factor for reward calculation
    uint private _remainingSupply; // The remaining token supply

    // Variables for AdjustFactor calculation
    // Total Rewards released until the current block height
    uint private _accumulatedReward;
    // Total Rewards from _startHeight to one PACE before lastMintHeight for one-day reward calculation
    uint private _accumRewards2PrevPACE;
    // Block height at which the most recent minting occurred.
    uint private _lastMintHeight; 

    // Constants
    uint constant MAX_SUPPLY = 2e9;                                             // 2 billion total supply
    uint constant PACE = 2880;                                                  // blocks per day
    uint constant MIN_INTERVAL = 2800;                                          // Minimum time interval (blocks) between mints
    uint constant DAILY_FACTOR_RATEBASE = 1e17;                                 // Rate base for daily factor calculation
    uint constant DAILY_FACTOR = 31645547929815;                                // {1 - 0.5^[1 / (365 * 6)]} * DAILY_FACTOR_RATEBASE
    uint constant ADJUSTFACTOR_RATEBASE = 1e3;                                  // Rate base for adjust factor
    uint constant INITIAL_ADJUSTFACTOR = 1e5;                                   // Initial adjust factor (100)
    uint constant MIN_ADJUSTFACTOR = 10;                                        // The minimal adjust factor (1/100)
    uint constant MAX_ADJUSTFACTOR = 1e7;                                       // The maximimal adjust factor (10000)
    uint constant MAX_ADJUSTFACTOR_RENEW = 2;                                   // Maximum adjust factor renewal range (1/2 to 2)
    address constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD; //Burn address

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        // Initialize contract state upon deployment
        _startHeight = block.number;
        _adjustFactor = INITIAL_ADJUSTFACTOR;
        _remainingSupply = maxSupply();
    }

    /// @notice Binds a minter address to a miner.
    /// @param minerId The unique identifier of the miner.
    /// @param minter The address to be bound to the miner, allowing it to submit mint requests.
    /// @dev Note: Owner, Worker, and all Controller addresses have the authority to bind minters.
    /// @dev Note: The old minter (if existing) will be replaced when binding a new one. 
    function bindMiner(uint64 minerId, address minter) external {
        address sender = _msgSender();
        require(FilecoinAPI.isControllingAddress(minerId, sender), 
            "Only a controller address can bind a minter to a miner");
        _minerBindsMap[minerId] = minter;
        emit Bind(minerId, minter, sender);
    }

    /// @notice Unbinds the minter address from a miner.
    /// @param minerId: The identifier of the miner
    /// @dev Note: Only controlling addresses are allowed to mint after unbinding
    function unbindMiner(uint64 minerId) isMinterOrControllingAddr(minerId) external {
        delete _minerBindsMap[minerId];
        emit Unbind(minerId, _msgSender());
    }

    /// @notice Mint rewards for a miner. Minting can be initiated by the miner's controllers or a bound minter.
    /// @param minerId: The unique identifier of the miner.
    /// @return The amount of tokens minted as a reward.
    function mint(uint64 minerId) isMinterOrControllingAddr(minerId) external returns(uint) {
        _adjustFactorRenew();
        uint amount = calculateRewardAmount(minerId);
        require(amount > 0, "Minting failed, please follow the rules");
        uint current = block.number;
        _lastMintHeight = current;
        _prevHeight[minerId] = current;
        _released[current] += amount;
        _remainingSupply -= amount;
        _accumulatedReward += amount;
        _mint(_msgSender(), amount);
        emit MinerMint(minerId, _msgSender(), amount);
        return amount;
    }

    /// @notice Calculate the reward amount based on the current miner's status.
    /// @param minerId: The unique identifier of the miner for which to calculate the reward.
    /// @return amount: The calculated reward amount in tokens.
    /// @dev Rules for reward calculation:
    ///   1. The current block height must be greater than or equal to the previous height plus MIN_INTERVAL (2800 blocks).
    ///   2. A miner can only claim one day's worth of reward.
    ///   3. The miner cannot receive a reward if their raw power is less than the consensus minimum (10 TiB).   
    ///   4. The maximum one-time reward for a miner should not exceed one-day reward
    function calculateRewardAmount(uint64 minerId) public view returns (uint) {
        uint currentBlock = block.number;
        uint previousBlock = _prevHeight[minerId];

        // Check if the miner is eligible for rewards based on rules.
        if (previousBlock + MIN_INTERVAL > currentBlock) {
            return 0; // Reward is not available due to insufficient time passed.
        }

        (uint minerRawPower, bool meetsConsensusMinimum) = FilecoinAPI.minerRawPower(minerId);
        if (!meetsConsensusMinimum) {
            return 0; // Reward is not available due to insufficient raw power.
        }

        // Calculate the pace of block generation within PACE (one day).
        uint pace = currentBlock - previousBlock;
        if (pace > PACE) {
            pace = PACE;
        }

        // Calculate the reward amount based on various factors.
        uint todayExpectedReward = todayReward();
        uint amount = todayExpectedReward * pace / PACE * _adjustFactor / ADJUSTFACTOR_RATEBASE * minerRawPower / FilecoinAPI.networkRawPower();

        // Ensure the calculated amount does not exceed the one-day reward.
        if (amount > todayExpectedReward) {
            amount = todayExpectedReward;
        }

        return amount;
    }

    /// @return amount: The maximum supply in attoRFIL
    function maxSupply() public view returns (uint) {
        return MAX_SUPPLY * 10 ** decimals();
    }

    /// @notice Calculate one-day reward for the current day.
    /// @dev Token distribution: halve every six years, following Filecoin original definition
    ///     6 years = 365 x 6 days = 2190 days
    ///     todayReward = remainingSupply * (1 - 0.5^(1/2190))
    ///                  = remainingSupply * 0.00031645547929815
    function todayReward() public view returns (uint) {
        return _remainingSupply * DAILY_FACTOR / DAILY_FACTOR_RATEBASE;
    }

    /// @notice Get the previous height at which the specific miner successfully minted RFIL.
    function prevHeight(uint64 minerId) external view returns (uint) {
        return _prevHeight[minerId];
    }

    /// @notice Get the minter address bound to a specific miner.
    function minerBindsMap(uint64 minerId) external view returns (address) {
        return _minerBindsMap[minerId];
    }

    /// @notice Get the total released RFIL token at a specific height (block number).
    function releasedOnHeight(uint64 height) external view returns (uint) {
        return _released[height];
    }

    /// @notice Get various factors and state variables related to the contract's configuration.
    function getFactors() external view returns (uint, uint, uint, uint, uint, uint) {
        return (_startHeight, _adjustFactor, _remainingSupply, _accumulatedReward, _accumRewards2PrevPACE, _lastMintHeight);
    }

    /// @notice Modifier to restrict mint functions to either the miner's bound address or controlling address.
    modifier isMinterOrControllingAddr(uint64 minerId) {
        address sender = _msgSender();
        require(sender == _minerBindsMap[minerId] || FilecoinAPI.isControllingAddress(minerId, sender), "Not bind or controlling address");
        _;
    }


    /// @notice Renew the AdjustFactor right after a reward is minted by a miner every time
    /// refer to https://github.com/RawFilecoin/RawFilecoin/blob/main/README.md#adjustfactor-renew to get details
    /// @dev To calculate todayReleasedReward, a moving accumulatedReward is counted, 
    ///      and also we count accumulatedRewardLastCut (1 day before) whenever we do the calculation, 
    ///      then, we have: 
    ///           todayReleasedReward = accumulatedReward - accumulatedRewardLastCut - rewardInBetween
    ///
    /// StartPoint         (lastMintHeight-PACE)     curHeight-PACE         (lastMintHeight)           curHeight
    ///  |-----------------------------|-------------------|------------------------|----------------------|
    ///  |--- _accumRewards2PrevPACE --|- RewardInBetween -|----------- todayReleasedReward ---------------|
    ///  |------------------------------------- accumulatedReward -----------------------------------------|
    function _adjustFactorRenew() private {
        uint curHeight = block.number;
        uint onePACE2Now = curHeight - PACE;

        if (_lastMintHeight < onePACE2Now){
            // No minting activity occurred during the last PACE period (one day)
            _accumRewards2PrevPACE = _accumulatedReward;

            // Move the reward to the next PACE period
            // Directly renew the adjust factor by the maximum allowed renewal rate
            _adjustFactor *= MAX_ADJUSTFACTOR_RENEW;
            // To prevent overflow
            if (_adjustFactor > MAX_ADJUSTFACTOR) _adjustFactor = MAX_ADJUSTFACTOR; 
        } else {
            // Or, there must be successful minting(s) happened in the last PACE period (one day)
            // To calculate accumulatedReward Until today's start height
            // and to move the _lastCutHeight (_lastMintHeight - PACE) to today's start height
            // and remove unuseful _released to save storage
            for (uint i = _lastMintHeight - PACE; i < onePACE2Now; i++){
                _accumRewards2PrevPACE += _released[i];
                delete _released[i];
            }

            // Now, the _accumRewards2PrevPACE is exactly to one PACE before curHeight
            uint todayReleased = _accumulatedReward - _accumRewards2PrevPACE;

            // Use ADJUSTFACTOR_RATEBASE for integer calculation with precision
            uint r = todayReward() * ADJUSTFACTOR_RATEBASE / todayReleased;
            if (r > ADJUSTFACTOR_RATEBASE * MAX_ADJUSTFACTOR_RENEW)
                r = ADJUSTFACTOR_RATEBASE * MAX_ADJUSTFACTOR_RENEW;
            if (r < ADJUSTFACTOR_RATEBASE / MAX_ADJUSTFACTOR_RENEW)
                r = ADJUSTFACTOR_RATEBASE / MAX_ADJUSTFACTOR_RENEW;
            _adjustFactor *= r;
            _adjustFactor /= ADJUSTFACTOR_RATEBASE;
            if (_adjustFactor > MAX_ADJUSTFACTOR) _adjustFactor = MAX_ADJUSTFACTOR;
            if (_adjustFactor < MIN_ADJUSTFACTOR) _adjustFactor = MIN_ADJUSTFACTOR;
        }
    }

    /// @notice Burn tokens if sent to defined burn address
    function transfer(address to, uint256 amount) public override returns (bool) {
        if (to == BURN_ADDRESS) {
            _burn(msg.sender, amount);
            return true;
        }
        return super.transfer(to, amount);
    }
}
