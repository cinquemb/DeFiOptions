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

import '@pangolindex/exchange-contracts/contracts/pangolin-core/interfaces/IPangolinFactory.sol';
import '@pangolindex/exchange-contracts/contracts/pangolin-core/interfaces/IPangolinPair.sol';
import '../utils/PangolinOracleLibrary.sol';
import '../utils/PangolinLibrary.sol';
import '../utils/Decimal.sol';
import '../interfaces/IDEXOracleV1.sol';

contract DEXOracleV1 is IDEXOracleV1 {
    using Decimal for Decimal.D256;

    address internal _pairAddr;
    address internal _exchange;
    address internal _underlying;
    address internal _stablecoin;

    uint256 internal _index;
    uint256 internal _reserve;
    uint256 internal _cumulative;

    bool private _latestValid;
    bool internal _initialized;

    uint32 internal _timestamp;
    int256 private _latestPrice;
    IPangolinPair internal _pair;

    /*TODO:
        NEED TO HARD CODE TWAP TIME  AND KEEP TRACK OF LAST TIME SUCCESFUL CAPTURE HAPPENED
    */


    constructor (address exchange, address underlying, address stable, address dexTokenPair) public {
        _exchange = exchange;
        _underlying = underlying;
        _stablecoin = stable;
        _pairAddr = dexTokenPair;
        
        _pair = IPangolinPair(_pairAddr);
        (address token0, address token1) = (_pair.token0(), _pair.token1());
        _index = _underlying == token0 ? 0 : 1;
        require(_index == 0 || _underlying == token1, "DEXOracleV1: Underlying not found");

        /*TODO:
            NEED TO CHECK THAT _stablecoin is in the approved stablecoins used on exchange 
        */
    }

    /**
     * Trades/Liquidity: (1) Initializes reserve and blockTimestampLast (can calculate a price)
     *                   (2) Has non-zero cumulative prices
     *
     * Steps: (1) Captures a reference blockTimestampLast
     *        (2) First reported value
     */
    function capture() public onlyExchange returns (int256, bool) {
        if (_initialized) {
            return updateOracle();
        } else {
            initializeOracle();
            return updateOracle();
        }
    }

    function initializeOracle() private {
        IPangolinPair pair = _pair;
        uint256 priceCumulative = _index == 0 ?
            pair.price0CumulativeLast() :
            pair.price1CumulativeLast();
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = pair.getReserves();
        if(reserve0 != 0 && reserve1 != 0 && blockTimestampLast != 0) {
            _cumulative = priceCumulative;
            _timestamp = blockTimestampLast;
            _initialized = true;
            _reserve = _index == 0 ? reserve1 : reserve0; // get counter's reserve
        }
    }

    function updateOracle() private returns (int256, bool) {
        int256 price = updatePrice();
        uint256 lastReserve = updateReserve();

        bool valid = true;

        if (price < 1e8) {
            valid = false;
        }

        _latestValid = valid;
        _latestPrice = price;

        return (price, valid);
    }

    function updatePrice() private returns (int256) {
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) =
        PangolinOracleLibrary.currentCumulativePrices(address(_pair));
        uint32 timeElapsed = blockTimestamp - _timestamp; // overflow is desired
        uint256 priceCumulative = _index == 0 ? price0Cumulative : price1Cumulative;
        Decimal.D256 memory price = Decimal.ratio((priceCumulative - _cumulative) / timeElapsed, 2**112);

        _timestamp = blockTimestamp;
        _cumulative = priceCumulative;

        return int256(price.mul(1e8).asUint256());
    }

    function updateReserve() private returns (uint256) {
        uint256 lastReserve = _reserve;
        (uint112 reserve0, uint112 reserve1,) = _pair.getReserves();
        _reserve = _index == 0 ? reserve1 : reserve0; // get counter's reserve

        return lastReserve;
    }

    function liveReserve() external view returns (uint256) {
        (uint112 reserve0, uint112 reserve1,) = _pair.getReserves();
        uint256 lastReserve = _index == 0 ? reserve1 : reserve0; // get counter's reserve

        return lastReserve;
    }

    function stablecoin() internal view returns (address) {
        return _stablecoin;
    }

    function pair() external view returns (address) {
        return _pairAddr;
    }

    function latestPrice() public view returns (int256) {
        return _latestPrice;
    }

    function latestValid() public view returns (bool) {
        return _latestValid;
    }

    modifier onlyExchange() {
        require(msg.sender == _exchange, "DEXOracleV1: Not exchange");

        _;
    }
}