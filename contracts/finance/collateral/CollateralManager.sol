pragma solidity >=0.6.0;
pragma experimental ABIEncoderV2;

import "./BaseCollateralManager.sol";
import "../../interfaces/IGovernableLiquidityPool.sol";
import "../../interfaces/IBaseHedgingManager.sol";

contract CollateralManager is BaseCollateralManager {

    using SafeCast for uint;
    using SafeMath for uint;
    using SignedSafeMath for int;

    struct CollateralData {
        address udlAddr;
        address hmngr;
        bool udlFound;
        int udlFoundIdx;
        int coll;
        int totalDelta;
        int hedgedDelta;
        uint totalAbsDelta;
        address[] underlyings;
        address[] rawUnderlyings;
        int[] _iv;
        uint[] posDeltaNum;
        uint[] posDeltaDenom;
        IOptionsExchange.OptionData[] options;
    }

    function initialize(Deployer deployer) override internal {
        super.initialize(deployer);
    }

    function calcNetCollateralInternal(address[] memory _tokens, uint[] memory _uncovered, uint[] memory _holding, bool is_regular) override internal view returns (int) {
        // multi udl feed refs, need to make core accross all collateral models
        // do not normalize by volumeBase in internal calls for calcCollateralInternal
        

        CollateralData memory cData;
        cData.posDeltaNum = new uint[](_tokens.length);
        cData.posDeltaDenom = new uint[](_tokens.length);
        cData._iv = new int[](_tokens.length);
        cData.options = new IOptionsExchange.OptionData[](_tokens.length);
        cData.underlyings = new address[](_tokens.length);
        cData.rawUnderlyings = new address[](_tokens.length);
        cData.coll = 0;

        //get the underlyings and option data
        for (uint i = 0; i < _tokens.length; i++) {
            IOptionsExchange.OptionData memory opt = exchange.getOptionData(_tokens[i]);
            cData.options[i] = opt;
            cData._iv[i] = calcIntrinsicValue(opt);
            cData.rawUnderlyings[i] = UnderlyingFeed(opt.udlFeed).getUnderlyingAddr();
        }
        //for each underlying calculate the delta of their sub portfolio
        for (uint i = 0; i < _tokens.length; i++) {
            cData.udlAddr = cData.rawUnderlyings[i];            
            (cData.udlFound, cData.udlFoundIdx) = foundUnderlying(cData.udlAddr, cData.underlyings);
            
            if (cData.udlFound == false) {
                cData.totalDelta = 0;
                cData.totalAbsDelta = 0;

                for (uint j = 0; j < _tokens.length; j++) {
                    address udlTemp = cData.rawUnderlyings[j];
                    if (udlTemp == cData.udlAddr){
                        (int256 delta, uint256 absDelta) = internalDeltaSum(cData.options[j], _uncovered[j], _holding[j]);
                        cData.totalDelta = cData.totalDelta.add(delta);
                        cData.totalAbsDelta = cData.totalAbsDelta.add(absDelta);
                    }
                }

                cData.underlyings[i] = cData.udlAddr;
                cData.posDeltaNum[i] = MoreMath.abs(cData.totalDelta);
                cData.posDeltaDenom[i] = cData.totalAbsDelta;

                cData.totalDelta = 0;
                cData.totalAbsDelta = 0;

                cData.udlFound = true;
            } else {
                // copy preexisting
                cData.underlyings[i] = cData.underlyings[uint(cData.udlFoundIdx)];
                cData.posDeltaNum[i] = cData.posDeltaNum[uint(cData.udlFoundIdx)];
                cData.posDeltaDenom[i] = cData.posDeltaDenom[uint(cData.udlFoundIdx)];
            }

            if (is_regular == false) {
                if (_uncovered[i] > _holding[i]) {
                    continue;
                }
            }

            cData.coll = sumCollateralCosts(cData, cData.options[i], cData._iv, _uncovered, _holding, i);
        }

        return cData.coll;
    }


    function calcCollateralInternal(address owner, bool is_regular) override internal view returns (int) {
        // multi udl feed refs, need to make core accross all collateral models
        // do not normalize by volumeBase in internal calls for calcCollateralInternal
        

        CollateralData memory cData;
        (,address[] memory _tokens, uint[] memory _holding,, uint[] memory _uncovered, int[] memory _iv, address[] memory _underlying) = exchange.getBook(owner);

        cData.underlyings = new address[](_tokens.length);
        cData.posDeltaNum = new uint[](_tokens.length);
        cData.posDeltaDenom = new uint[](_tokens.length);
        cData.hmngr = (settings.checkPoolSellCreditTradable(owner)) ? IGovernableLiquidityPool(owner).getHedgingManager() : address(0); //HACK: checks if owner is a pool that can sell options with borrowed liquidity
        
        //for each underlying calculate the delta of their sub portfolio
        for (uint i = 0; i < _underlying.length; i++) {
            IOptionsExchange.OptionData memory opt = exchange.getOptionData(_tokens[i]);

            cData.udlAddr = _underlying[i];
            (cData.udlFound, cData.udlFoundIdx) = foundUnderlying(cData.udlAddr, cData.underlyings);
            if (cData.udlFound == false) {
                cData.totalDelta = 0;
                cData.hedgedDelta = 0;
                cData.totalAbsDelta = 0;

                if (settings.isAllowedHedgingManager(cData.hmngr)) {
                     cData.hedgedDelta = int256(
                        IBaseHedgingManager(cData.hmngr).realHedgeExposure(
                           cData.udlAddr
                        )
                    );
                }
                
                for (uint j = 0; j < _tokens.length; j++) {
                    if (_underlying[j] == cData.udlAddr){
                        (int256 delta, uint256 absDelta) = internalDeltaSum(opt, _uncovered[j], _holding[j]);
                        cData.totalDelta = cData.totalDelta.add(delta);
                        cData.totalAbsDelta = cData.totalAbsDelta.add(absDelta);
                    }
                }
                cData.underlyings[i] = cData.udlAddr;
                cData.posDeltaNum[i] = MoreMath.abs(cData.totalDelta.sub(cData.hedgedDelta));
                cData.posDeltaDenom[i] = cData.totalAbsDelta;

                cData.totalDelta = 0;
                cData.hedgedDelta = 0;
                cData.totalAbsDelta = 0;

                cData.udlFound = true;
            } else {
                // copy preexisting
                cData.underlyings[i] = cData.underlyings[uint(cData.udlFoundIdx)];
                cData.posDeltaNum[i] = cData.posDeltaNum[uint(cData.udlFoundIdx)];
                cData.posDeltaDenom[i] = cData.posDeltaDenom[uint(cData.udlFoundIdx)];
            }

            if (is_regular == false) {
                if (_uncovered[i] > _holding[i]) {
                    continue;
                }
            }

            cData.coll = sumCollateralCosts(cData, opt, _iv, _uncovered, _holding, i);
        }
        return cData.coll;
    }

    function internalDeltaSum(IOptionsExchange.OptionData memory opt, uint _uncovered, uint _holding) private view returns (int delta, uint256 absDelta){
        if (_uncovered > 0) {
            // net short this option, thus mult by -1
            delta = calcDelta(
                opt,
                _uncovered
            ).mul(-1);
            absDelta = MoreMath.abs(delta);
        }

        if (_holding > 0) {
            // net long thus does not need to be modified
            delta = calcDelta(
                opt,
                _holding
            );
            absDelta = MoreMath.abs(delta);
        }
    }

    function sumCollateralCosts(CollateralData memory cData, IOptionsExchange.OptionData memory opt, int[] memory _iv, uint[] memory _uncovered, uint[] memory _holding, uint i) private view returns (int){
        if ((cData.posDeltaDenom[i] > 0) && (_uncovered[i] > _holding[i])) {
            cData.coll = cData.coll.add(
                _iv[i].mul(
                    int(_uncovered[i]).sub(int(_holding[i]))
                )
            ).add(
                int(
                    calcCollateral(
                        getFeedData(opt.udlFeed).upperVol,
                        _uncovered[i],
                        opt
                    ).mul(cData.posDeltaNum[i]).div(cData.posDeltaDenom[i])
                )
            );

            //apply coll reqs due to underlying asset shortage
            cData.coll = cData.coll.add(
                collateralSkewForPositionUnderlying(cData.coll, opt.udlFeed).mul(int(cData.posDeltaNum[i])).div(int(cData.posDeltaDenom[i]))
            );
        } else if ((_uncovered[i] > _holding[i])) {
            cData.coll = cData.coll.add(
                _iv[i].mul(
                    int(_uncovered[i]).sub(int(_holding[i]))
                )
            ).add(
                int(
                    calcCollateral(
                        getFeedData(opt.udlFeed).upperVol,
                        _uncovered[i],
                        opt
                    )
                )
            );

            //apply coll reqs due to underlying asset shortage
            cData.coll = cData.coll.add(
                collateralSkewForPositionUnderlying(cData.coll, opt.udlFeed)
            );
        }

        return cData.coll;
    }

    function foundUnderlying(address udl, address[] memory udlArray) private pure returns (bool, int){
        for (uint i = 0; i < udlArray.length; i++) {
            if (udlArray[i] == udl) {
                return (true, int(i));
            }
        }

        return (false, -1);
    }

    function calcCollateral(
        IOptionsExchange.OptionData calldata opt,
        uint volume
    ) override external view returns (uint)
    {
        IOptionsExchange.FeedData memory fd = getFeedData(opt.udlFeed);
        if (fd.lowerVol == 0 || fd.upperVol == 0) {
            fd = getFeedData(opt.udlFeed);
        }

        int coll = calcIntrinsicValue(opt).mul(int(volume)).add(
            int(calcCollateral(fd.upperVol, volume, opt))
        ).div(int(_volumeBase));

        if (opt._type == IOptionsExchange.OptionType.PUT) {
            int max = int(uint(opt.strike).mul(volume).div(_volumeBase));
            coll = MoreMath.min(coll, max);
        }

        return coll > 0 ? uint(coll) : 0;
    }

    function calcDelta(
        IOptionsExchange.OptionData memory opt,
        uint volume
    ) public view returns (int256){
        (,, int256 d1) = calcDeltaInternal(opt);
        int256 delta;

        if (opt._type == IOptionsExchange.OptionType.PUT) {
            // -1 * norm_cdf(-d1) == put_delta
            delta = MoreMath.cdf(d1.mul(-1)).mul(-1);
        
        } else {
            // norm_cdf(d1) == call_delta
            delta = MoreMath.cdf(d1);
        }

        require((-1e18 <= delta) && (delta <= 1e18), "delta out of range");
        return delta.mul(int256(volume)).div(int256(_volumeBase));
    }

    function calcGamma(
        IOptionsExchange.OptionData memory opt,
        uint volume
    ) public view returns (int256){
        (uint256 price, int256 d1d, int256 d1) = calcDeltaInternal(opt);

        int256 gamma = MoreMath.pdf(d1).mul(int256(_volumeBase)).div(
            int256(price.mul(uint256(d1d)).div(_volumeBase))
        );

        //require((-1e18 <= gamma) && (gamma <= 1e18), "gamma out of range");
        return gamma.mul(int256(volume)).div(int256(_volumeBase));
    }

    function calcDeltaInternal(
        IOptionsExchange.OptionData memory opt
    ) private view returns (uint256 price, int256 d1d, int256 d1){
        /* 
            - rfr == 0% assumption
            - (1 / (sigma * sqrt(T - t))) * (ln(S/k) + (((sigma**2) / 2) * ((T-t)))) == d1
                - underlying price S
                - strike price K
        */

        uint256 one_year = 60 * 60 * 24 * 365;
        uint256 volPeriod = settings.getVolatilityPeriod();
        
        // using exchange 90 day window
        price = uint256(getUdlPrice(opt));
        uint256 sigma = UnderlyingFeed(opt.udlFeed).getDailyVolatility(volPeriod).mul(_volumeBase).mul(3).mul(10).div(price); //vol
        int256 price_div_strike = int256(price).mul(int256(_volumeBase)).div(int256(opt.strike));//need to multiply by volume base to get a number in base 1e18 decimals

        //giv expired options no delta
        if (uint256(opt.maturity) < settings.exchangeTime()){
            return (price,0,0);
        }
        uint256 dt = (uint256(opt.maturity).sub(settings.exchangeTime())).mul(_volumeBase).div(one_year); //dt relative to a year;

        int256 ln_price_div_strike = MoreMath.ln(price_div_strike);

        int256 d1n = int256((MoreMath.pow(sigma, 2).div(_volumeBase)).mul(dt).div(2).div(_volumeBase));
        d1d = int256(sigma.mul(MoreMath.sqrt(dt)).mul(1e9).div(_volumeBase));//div(_sqrtBase)

        d1 = (ln_price_div_strike.add(
            d1n
        )).mul(int256(_volumeBase)).div(
            d1d
        );
    }

    function borrowTokensByPreference(address to, address pool, uint value, address[] calldata tokensInOrder, uint[] calldata amountsOutInOrder) external {
        creditProvider.borrowTokensByPreference(to, pool, value, tokensInOrder, amountsOutInOrder);
    }

    function borrowCreditFromPool(address to, address pool, uint value) external {
        creditProvider.borrowCreditFromPool(to, pool, value);
    }
}