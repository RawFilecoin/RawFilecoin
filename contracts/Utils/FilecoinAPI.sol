// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "filecoin-solidity-api/contracts/v0.8/types/CommonTypes.sol";
import "filecoin-solidity-api/contracts/v0.8/types/PowerTypes.sol";
import "filecoin-solidity-api/contracts/v0.8/PowerAPI.sol";
import "filecoin-solidity-api/contracts/v0.8/MinerAPI.sol";
import "filecoin-solidity-api/contracts/v0.8/utils/FilAddresses.sol";
import "filecoin-solidity-api/contracts/v0.8/utils/FilAddressIdConverter.sol";

import "./Conversion.sol";

library FilecoinAPI{
    using Conversion for *;

    string constant errMsg = "Error occured";

    function isControllingAddress(uint64 minerId, address addr) internal view returns (bool) {
        (int256 exitCode, bool result) = MinerAPI.isControllingAddress(CommonTypes.FilActorId.wrap(minerId), ethAddress2FilAddress(addr));
        require(exitCode == 0, errMsg);
        return result;
    }

    function networkRawPower() internal view returns (uint raw_byte_power) {
        (int256 exitCode, CommonTypes.BigInt memory result) = PowerAPI.networkRawPower();
        require(exitCode == 0, errMsg);
        raw_byte_power = result.bigInt2Uint();
    }

    function minerRawPower(uint64 minerId) internal view returns (uint raw_byte_power, bool meets_consensus_minimum) {
        (int256 exitCode, PowerTypes.MinerRawPowerReturn memory result) = PowerAPI.minerRawPower(minerId);
        require(exitCode == 0, errMsg);
        raw_byte_power = result.raw_byte_power.bigInt2Uint();
        meets_consensus_minimum = result.meets_consensus_minimum;
    }

    function ethAddress2FilAddress(address account) private view returns (CommonTypes.FilAddress memory addr) {
        (bool success, uint64 id) = FilAddressIdConverter.getActorID(account);
        require(success, errMsg);
        return FilAddresses.fromActorID(id);
    }
}