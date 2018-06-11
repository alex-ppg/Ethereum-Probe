pragma solidity ^0.4.24;

contract EthereumProbe {
    event PaidForAccess(address indexed _payee, uint256 _timestamp);

    address private beneficiary;
    uint96 public accessPrice = 10 finney;
    address private owner;

    modifier isOwner() {
        assert(msg.sender == owner);
        _;
    }

    modifier eligibleForAccess() {
        assert(msg.value == accessPrice);
        _;
    }

    constructor(address _beneficiary) public {
        beneficiary = _beneficiary;
        owner = msg.sender;
    }

    function() payable public eligibleForAccess {
        beneficiary.transfer(msg.value);
        emit PaidForAccess(msg.sender, now);
    }

    function changeBeneficiary(address _beneficiary) external isOwner {
        beneficiary = _beneficiary;
    }

    function changeOwner(address _owner) external isOwner {
        owner = _owner;
    }

    function changePrice(uint96 _accessPrice) external isOwner {
        accessPrice = _accessPrice;
    }
}
