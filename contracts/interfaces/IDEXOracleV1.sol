/*
    Copyright 2021 DeFi Options, based on the works of the Empty Set Squad

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/

pragma solidity ^0.5.17;
pragma experimental ABIEncoderV2;

import "../utils/Decimal.sol";

contract IOracle {
    function setup() public;
    function capture() public returns (int256, bool);
    function pair() external view returns (address);
    function liveReserve() external view returns (uint256);
    function latestPrice() public view returns (int256 memory);
    function latestValid() public view returns (bool);
}