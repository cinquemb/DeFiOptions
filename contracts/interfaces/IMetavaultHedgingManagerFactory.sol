pragma solidity >=0.6.0;


interface IMetavaultHedgingManagerFactory {

    function _readerAddr() external returns (address);
    function _positionManagerAddr() external returns (address);
    function _referralCode() external returns (bytes32);

    function create(address _poolAddr) external returns (address);
}