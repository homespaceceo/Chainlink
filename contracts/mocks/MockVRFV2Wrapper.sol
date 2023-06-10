// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";

interface IVRFConsumer {
    function rawFulfillRandomWords(uint256 requestId_, uint256[] memory randomWords_) external;
}

contract MockVRFV2Wrapper {
    using Counters for Counters.Counter;

    Counters.Counter public counter;

    constructor() {}

    function onTokenTransfer(address /* _sender */, uint /* _value */, bytes memory /* _data */) external {
        counter.increment();
    }

    function provide(IVRFConsumer consumer_, uint256 requestId_, uint256[] memory randomWords_) external {
        consumer_.rawFulfillRandomWords(requestId_, randomWords_);
    }

    function calculateRequestPrice(uint32 /* _callbackGasLimit */) external pure returns (uint256) {
        return 1e18;
    }

    function lastRequestId() external view returns (uint256) {
        return counter.current();
    }
}
