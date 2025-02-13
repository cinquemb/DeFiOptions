pragma solidity >=0.6.0;

import "../../../contracts/governance/Proposal.sol";
import "../../../contracts/interfaces/IProtocolSettings.sol";

contract TransferBalanceProposal is Proposal {

    uint amount;

    function setAmount(uint _amount) public {

        require(_amount > 0);

        amount = _amount;
    }

    function getName() public override view returns (string memory) {

        return "Transfer Balance";
    }

    function execute(IProtocolSettings settings) public override {
        
        require(amount > 0, "amount not set");
        settings.transferBalance(address(this), amount);
    }

    function executePool(IERC20 _llp) public override {}
}