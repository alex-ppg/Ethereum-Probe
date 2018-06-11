const RPCProvider = require('ethers').providers.JsonRpcProvider;
const Contract = require('ethers').Contract;

// This address will work with the Ganache Local Node
const providerInstance = new RPCProvider('http://127.0.0.1:7545');

// Change this address appropriately to your contract's address
const contractAddress = '0xd8bbf36b8b1a5abb3144dc5727969bcfcd53e0db';

// Although this ABI is for the secure version, it will also work for the basic one as the event name is the same
const contractABI = require('./contractABI.json');

// We create contract instance combining the above variables
const contractInstance = new Contract(contractAddress, contractABI, providerInstance);

// The values are passed on to the callback function in an index-based way, so the first variable holds the first emitted variable and so forth
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
