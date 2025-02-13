pragma solidity >=0.6.0;
pragma experimental ABIEncoderV2;

import "../deployment/ManagedContract.sol";
import "../pools/GovernableLinearLiquidityPool.sol";

contract LinearLiquidityPoolFactory is ManagedContract {

    address private deployerAddress;

    function initialize(Deployer deployer) override internal {
        deployerAddress = address(deployer);
    }

    function create(string calldata name, string calldata symbolSuffix, bool _onlyMintToOwner, address _owner) external returns (address) {
        //address proxyAddr = address(
        //    new Proxy(
        //        ManagedContract(deployerAddress).getOwner(),
        return address(new GovernableLinearLiquidityPool(name, symbolSuffix, deployerAddress, _onlyMintToOwner, _owner));
        //    )
        //);
        //ManagedContract(proxyAddr).initializeAndLock(Deployer(deployerAddress));
        //return proxyAddr;
    }
}