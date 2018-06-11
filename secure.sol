pragma solidity ^0.4.24;

contract EthereumProbe {
    event PaidForAccess(address indexed _payee, uint256 _timestamp);

    address private beneficiary;
    uint96 public accessPrice = 10 finney;
    address private owner;
    address private nextBeneficiary;
    address private nextOwner;

    modifier isOwner() {
        assert(msg.sender == owner);
        _;
    }

    modifier isNextBeneficiary() {
        assert(msg.sender == nextBeneficiary);
        _;
    }

    modifier isNextOwner() {
        assert(msg.sender == nextOwner);
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

    function inviteNewBeneficiary(address _nextBeneficiary) external isOwner {
        nextBeneficiary = _nextBeneficiary;
    }

    function acceptBeneficiaryInvite() external isNextBeneficiary {
        beneficiary = nextBeneficiary;
    }

    function inviteNewOwner(address _nextOwner) external isOwner {
        nextOwner = _nextOwner;
    }

    function acceptOwnershipInvite() external isNextOwner {
        owner = nextOwner;
    }

    function changePrice(uint96 _accessPrice) external isOwner {
        accessPrice = _accessPrice;
    }
}
