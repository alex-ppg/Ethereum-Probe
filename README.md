# **Ethereum Probe**
This smart contract can be used to activate an external (out-of-blockchain) process through a payment on the Ethereum blockchain.

Although the code present within this website has been vetted & rigorously analyzed, I do not offer any guarantee that usage of any material on this site can be deemed secure & **I cannot be held liable for any negative impact resulting from the usage of this website**.

# **Introduction**
This smart contract aims to bridge the gap that exists between blockchain and non-blockchain operations. By taking advantage of [the Ethereum Virtual Machine logging facilities](http://solidity.readthedocs.io/en/v0.4.21/contracts.html#events), one can emit an Event, a log that will be attached to the transaction's receipt. This in turn enables an Ethereum Node listening for the event's cryptographic signature to be notified when it is attached on a transaction receipt.

While relying on a public Ethereum Node to reliably report any such events that would be created defeats the purpose of them as public nodes can lie, **running your own Ethereum Node connected to the main-net would be trustworthy for taking action on emitted events**. This enables complex services to operate such as an access control pattern based on the receipt of a payment.

Such a case is showcased in the exemplary contracts that are included in this repository. These contracts are split into two types, a *basic* one and a *secure* one. The term ***secure*** refers to the **additional measures taken to nullify human error**. These measures ensure that Ether will never be locked to an address compared to the ***basic*** implementation which relies on the owner of the contract to properly manage it.

---

# **Basic Smart Contract**

## Contract Variable Declarations

In the basic smart contract, we want to simply emit an event upon receipt of payment that matches a pre-specified sum and add a few management functions to change the owner and the beneficiary of the smart contract. In order to do this, we need to declare an `address` variable for the owner of the contract & for the beneficiary in addition to a `uint` variable that will hold the price of purchasing *access* to the service listening on the contract.

In order to fully take advantage of the EVM schematics, we will declare the `uint` variable as a 96-bit variable (`uint96`). This restricts the Ether cost of access to our service in the range of `0 <= x <= 79228162514.3` Ether, more than enough for an kind of service. The benefit of declaring the variable as such allows the EVM to [*tight-pack*](http://solidity.readthedocs.io/en/v0.4.24/miscellaneous.html#layout-of-state-variables-in-storage) the contract-variables efficiently, as an `address` (160-bits) and a `uint96` (96-bits) can both fit into a single word (32 bytes = 256 bits = 96 + 160).

Our final variable declaration looks as follows:

```sol
pragma solidity ^0.4.24;

contract EthereumProbe {
    address private beneficiary;
    uint96 public accessPrice = 10 finney;
    address private owner;
}
```

We want to enable our back-end to listen to the contract and act whenever the contract receives payment. As aforementioned, **this can be achieved via an emitted `Event`**. Before we actually emit an `Event`, we need to properly declare it within the contract. We also want the event to take two arguments, one being the `address` of a user while the other being a Unix timestamp of the transaction, enabling us to **time-limit** access to the service.

We also want to be able to listen for a specific `address` purchasing access, so we will use the reserved `indexed` keyword which will enable our back-end to filter incoming events.

As such, our `Event` declaration looks as follows:

```sol
pragma solidity ^0.4.24;

contract EthereumProbe {
    address private beneficiary;
    uint96 public accessPrice = 10 finney;
    address private owner;

    event PaidForAccess(address indexed _payee, uint256 _timestamp);
}
```

This concludes the variable declaration phase.

---

## Contract Functions

The `constructor` will include only a single argument, the `address` of the beneficiary of the contract. This is so as to separate the payment from the management to enable a multi-signature wallet to accept payments for example. It will also assign the `msg.sender` to the owner variable held within the contract:

```sol
constructor(address _beneficiary) public {
    beneficiary = _beneficiary;
    owner = msg.sender;
}
```

We now want to create a function for receiving payment and properly granting access should the `event` be emitted. The *granting access* part will be handled on the back-end snippets explained at a later point so lets focus on the contract side of things.

We also need to ensure that the value sent to the contract matches the price of access to prevent accidental transfers and transfer that value to the beneficiary. As such, we construct the function as follows:

```sol
function() payable public {
    assert(msg.value == accessPrice);
    beneficiary.transfer(msg.value);
    emit PaidForAccess(msg.sender, now);
}
```

Adding a few simple management functions for changing the values of the beneficiary, the owner as well as the access price:

```sol
function changeBeneficiary(address _beneficiary) external {
    assert(msg.sender == owner);
    beneficiary = _beneficiary;
}

function changeOwner(address _owner) external {
    assert(msg.sender == owner);
    owner = _owner;
}

function changePrice(uint96 _accessPrice) external {
    assert(msg.sender == owner);
    accessPrice = _accessPrice;
}
```

We now simply bundle the `assert` clauses into `modifier`s, resulting in the following final contract:

```sol
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
```

This concludes the explanation of the *basic* EthereumProbe smart contract.

---

# **Secure Smart Contract**

## Contract Variable Declarations

We want to ensure that the beneficiary and owner addresses are active addresses and not redundant (such as the `0x0` address). In order to do this, we break the owner & beneficiary migration into a two-step process that needs to be finalized by the counter-party being *invited*. As such, we require two additional variable declarations in addition to the basic ones above:

```sol
pragma solidity ^0.4.24;

contract EthereumProbe {
    event PaidForAccess(address indexed _payee, uint256 _timestamp);

    address private beneficiary;
    uint96 public accessPrice = 10 finney;
    address private owner;
    // New declarations below
    address private nextBeneficiary;
    address private nextOwner;
}
```

This concludes the variable declaration phase.

---

## Contract Functions

The only functions that change in this contract compared to the basic one are the owner & beneficiary management functions. Instead of having a single function for each, we break them into two called `inviteNewX` and `acceptXInvite` where `X` is either `Beneficiary` or `Ownership`.

On the `invite` functions, we simply save the address of the new beneficiary or owner within our smart contract in the appropriate variable.

On the `accept` functions, we allow only the new beneficiary or owner to call it and change the appropriate variable in the contract to accept the invitation.

As such, the final functions are:

```sol
function inviteNewBeneficiary(address _nextBeneficiary) external {
    assert(msg.sender == owner);
    nextBeneficiary = _nextBeneficiary;
}

function acceptBeneficiaryInvite() external {
    assert(msg.sender == nextBeneficiary);
    beneficiary = nextBeneficiary;
}

function inviteNewOwner(address _nextOwner) external {
    assert(msg.sender == owner);
    nextOwner = _nextOwner;
}

function acceptOwnershipInvite() external {
    assert(msg.sender == nextOwner);
    owner = nextOwner;
}
```

In addition to preventing the owner or beneficiary addresses to be redundant, these functions also enable a failsafe address to be pre-approved as an owner and, in the case of a lost private key, be used to regain ownership of the contract.

We now once again bundle the `assert` clauses into `modifier`s, resulting in the following final contract:

```sol
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
```

This concludes the explanation of the *secure* EthereumProbe smart contract.

---

# **Listening to the Smart Contract**

## Back-end (Node.JS)

After deploying the above contracts, we will get an `address` corresponding to the contract. This `address`, along with [the contract's ABI](https://github.com/ethereum/wiki/wiki/Ethereum-Contract-ABI), will be used to connect to it via an Ethereum Node and listen for an event.

In a back-end application running on Node.JS, we would preferably use the [`ethers.js` library](https://github.com/ethers-io/ethers.js/) which is more robust than `web3` for handling Ethereum interactions.

First, we need to install the package via `npm` on our repository:

```sh
npm install --save ethers
```

After that, we can create a `js` file and open it with our editor:

```sh
touch index.js
vim index.js
```

We now want to import a sub-set of the `ethers` package that enables us to listen to the Ethereum network. This sub-set is the `providers` subset which provides various wrappers for creating a `Provider` object. We specifically need the `JsonRpcProvider` as we will only connect directly to our hosted node. We also need to import the `Contract` subset that acts as a wrapper for communicating with smart contracts on an Ethereum network:

```js
const RPCProvider = require('ethers').providers.JsonRpcProvider;
const Contract = require('ethers').Contract;
```

Before we construct our `Contract` object, we need to supply it with a few things. Firstly, we need a `Provider` object through which we will communicate with the Ethereum blockchain directly. As such, we need to construct the `Provider` object by supplying it with an RPC URL of a node to connect to.

In the case of a real scenario, this would preferably be an internal port assignment so that only our program will connect through RPC to our node.

In this tutorial, we assume that you are running a [Ganache](http://truffleframework.com/ganache/) local client to test the network implementation and as such we use the default Ganache port:

```js
const RPCProvider = require('ethers').providers.JsonRpcProvider;
const Contract = require('ethers').Contract;

const providerInstance = new RPCProvider('http://127.0.0.1:7545');
```

We now need the contract's deployed address as well as its ABI. For the sake of keeping our code clean we will save the ABI in a file named `contractABI.json` and import it within our code:

```js
const RPCProvider = require('ethers').providers.JsonRpcProvider;
const Contract = require('ethers').Contract;

const providerInstance = new RPCProvider('http://127.0.0.1:7545');

// Change this address appropriately to your contract's address
const contractAddress = '0xd8bbf36b8b1a5abb3144dc5727969bcfcd53e0db';

const contractABI = require('./contractABI.json');
```

We simply need to construct our `Contract` instance now:

```js
const RPCProvider = require('ethers').providers.JsonRpcProvider;
const Contract = require('ethers').Contract;

const providerInstance = new RPCProvider('http://127.0.0.1:7545');

// Change this address appropriately to your contract's address
const contractAddress = '0xd8bbf36b8b1a5abb3144dc5727969bcfcd53e0db';

const contractABI = require('./contractABI.json');

const contractInstance = new Contract(contractAddress, contractABI, providerInstance);
```

With the `contractInstance` variable, we can now access and call any functions of the contract that do not alter the blockchain state. If we had supplied an actual account instead of a provider for the `Contract` constructor, we would also be able to call functions that alter the blockchain state.

In order to listen to an event, we need to supply a callback function to it. `ethers.js` by default creates a member of the `contractInstance` that follows the following naming convention:

```js
let eventName = 'PaidForAccess'
let memberName = 'on' + eventName.toLowerCase();
```

As such, we can assign the callback function to that member for our contract in the following way:

```js
contractInstance.onpaidforaccess = function() {
  // Handle callback
}
```

The arguments of the event are passed as-is to the callback function in an index-based format, so we can simply read them as follows:

```js
contractInstance.onpaidforaccess = function(payee, unix_timestamp) {
  // This will print the address of the payee
  console.log(payee);
  // This will print the Unix timestamp wrapped in a BigNumber object
  console.log(unix_timestamp);
}
```

By default, all numbers that are gotten from and passed to contracts are wrapped in a `BigNumber` object as the Ethereum network supports numbers up to 256-bit in length, significantly bigger than what Javascript inherently handles.

We now will print a notification message on the callback of the event that will print the address of the new user as well as the time the user was authorized:

```js
contractInstance.onpaidforaccess = function(payee, unix_timestamp) {
  // Date object of timestamp
  let date = new Date(unix_timestamp*1000);
  // Hours part from the timestamp
  let hours = date.getHours();
  // Minutes part from the timestamp
  let minutes = "0" + date.getMinutes();
  // Seconds part from the timestamp
  let seconds = "0" + date.getSeconds();
  // Output a notification message when the event is triggered
  console.log('New user authorized: ' + payee + ' at ' + hours + ':' + minutes.substr(-2) + ':' + seconds.substr(-2));
}
```

Bundling our snippet all together:

```js
const RPCProvider = require('ethers').providers.JsonRpcProvider;
const Contract = require('ethers').Contract;

const providerInstance = new RPCProvider('http://127.0.0.1:7545');

// Change this address appropriately to your contract's address
const contractAddress = '0xd8bbf36b8b1a5abb3144dc5727969bcfcd53e0db';

const contractABI = require('./contractABI.json');

const contractInstance = new Contract(contractAddress, contractABI, providerInstance);

contractInstance.onpaidforaccess = function(payee, unix_timestamp) {
  // Date object of timestamp
  let date = new Date(unix_timestamp*1000);
  // Hours part from the timestamp
  let hours = date.getHours();
  // Minutes part from the timestamp
  let minutes = "0" + date.getMinutes();
  // Seconds part from the timestamp
  let seconds = "0" + date.getSeconds();
  // Output a notification message when the event is triggered
  console.log('New user authorized: ' + payee + ' at ' + hours + ':' + minutes.substr(-2) + ':' + seconds.substr(-2));
}
```

The above snippet can also be found on the `example-node` subfolder of the repository ready-to-run.

# **Conclusion**

By utilizing the above code, one can create any form of service that interoprates with an Ethereum blockchain for receiving payments and commiting actions based on said payments.
