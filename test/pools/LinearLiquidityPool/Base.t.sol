pragma solidity >=0.6.0;

import "truffle/Assert.sol";
//import "truffle/DeployedAddresses.sol";
import "../../../contracts/deployment/Deployer.sol";
import "../../../contracts/finance/OptionsExchange.sol";
import "../../../contracts/finance/OptionToken.sol";
import "../../../contracts/governance/ProtocolSettings.sol";
import "../../../contracts/interfaces/IOptionsExchange.sol";
import "../../../contracts/interfaces/IGovernableLiquidityPool.sol";
import "../../../contracts/finance/CollateralManager.sol";
import "../../common/actors/PoolTrader.t.sol";
import "../../common/mock/ERC20Mock.t.sol";
import "../../common/mock/EthFeedMock.t.sol";
import "../../common/mock/TimeProviderMock.t.sol";
import "../../common/mock/UniswapV2RouterMock.t.sol";

contract Base {
    
    int ethInitialPrice = 550e18;
    uint strike = 550e18;
    uint maturity = 30 days;
    
    uint err = 1; // rounding error
    uint cBase = 1e6; // comparison base
    uint volumeBase = 1e18;
    uint timeBase = 1 hours;

    uint spread = 5e7; // 5%
    uint reserveRatio = 20e7; // 20%
    uint withdrawFee = 3e7; // 3%
    uint fractionBase = 1e9;

    EthFeedMock feed;
    ERC20Mock erc20;
    TimeProviderMock time;

    ProtocolSettings settings;
    OptionsExchange exchange;
    CollateralManager collateralManager;

    address pool;
    
    PoolTrader bob;
    PoolTrader alice;
    
    IOptionsExchange.OptionType CALL = IOptionsExchange.OptionType.CALL;
    IOptionsExchange.OptionType PUT = IOptionsExchange.OptionType.PUT;
    
    IGovernableLiquidityPool.Operation NONE = IGovernableLiquidityPool.Operation.NONE;
    IGovernableLiquidityPool.Operation BUY = IGovernableLiquidityPool.Operation.BUY;
    IGovernableLiquidityPool.Operation SELL = IGovernableLiquidityPool.Operation.SELL;

    uint120[] x;
    uint120[] y;
    uint[3] bsStockSpread;
    string symbol = "ETHM-EC-55e19-2592e3";

    Deployer deployer = new Deployer(address(0));

    function beforeEachDeploy() public {

        //Deployer deployer = Deployer(DeployedAddresses.Deployer());
        deployer.reset();
        deployer.deploy(address(this));
        time = TimeProviderMock(deployer.getContractAddress("TimeProvider"));
        feed = EthFeedMock(deployer.getContractAddress("UnderlyingFeed"));
        settings = ProtocolSettings(deployer.getContractAddress("ProtocolSettings"));
        exchange = OptionsExchange(deployer.getContractAddress("OptionsExchange"));
        pool = exchange.createPool("DEFAULT", "TEST", false, address(0));
        erc20 = ERC20Mock(deployer.getContractAddress("StablecoinA"));
        collateralManager = CollateralManager(deployer.getContractAddress("CollateralManager"));

        erc20.reset();

        settings.setAllowedToken(address(erc20), 1, 1);
        settings.setUdlFeed(address(feed), 1);

        IGovernableLiquidityPool(pool).setParameters(
            reserveRatio,
            withdrawFee,
            time.getNow() + 90 days,
            10,
            address(0),
            1000e18
        );

        feed.setPrice(ethInitialPrice);
        time.setFixedTime(0);
    }

    function createTraders() public {
        
        bob = createPoolTrader(address(erc20));
        alice = createPoolTrader(address(erc20));
    }

    function depositInPool(address to, uint value) public {
        
        erc20.issue(address(this), value);
        erc20.approve(address(pool), value);
        IGovernableLiquidityPool(pool).depositTokens(to, address(erc20), value);
    }

    function applyBuySpread(uint v) internal view returns (uint) {
        return (v * (spread + fractionBase)) / fractionBase;
    }

    function applySellSpread(uint v) internal view returns (uint) {
        return (v * (fractionBase - spread)) / fractionBase;
    }

    function addSymbol() internal {

        /*

            function addSymbol(
                address udlFeed,
                uint strike,
                uint _mt,
                IOptionsExchange.OptionType optType,
                uint t0,
                uint t1,
                uint120[] calldata x,
                uint120[] calldata y,
                uint[3] calldata bsStockSpread

        */

        x = [400e18, 450e18, 500e18, 550e18, 600e18, 650e18, 700e18];
        y = [
            30e18,  40e18,  50e18,  50e18, 110e18, 170e18, 230e18,
            25e18,  35e18,  45e18,  45e18, 105e18, 165e18, 225e18
        ];

        bsStockSpread = [
            100 * volumeBase, // buy stock
            200 * volumeBase,  // sell stock
            spread
        ];

        //TODO: agent needs to deposit in pool and create proposal for this, need to specify spread
        
        IGovernableLiquidityPool(pool).addSymbol(
            address(feed),
            strike,
            maturity,
            CALL,
            time.getNow(),
            time.getNow() + 1 days,
            x,
            y,
            bsStockSpread
        );

        exchange.createSymbol(address(feed), CALL, strike, maturity);
    }

    function calcCollateralUnit() internal view returns (uint) {

        return exchange.calcCollateral(
            address(feed), 
            volumeBase,
            CALL,
            strike,
            maturity
        );
    }

    function createPoolTrader(address stablecoinAddr) internal returns (PoolTrader) {

        return new PoolTrader(stablecoinAddr, address(exchange), address(pool), address(feed));  
    }
}