pragma solidity >=0.4.25 <0.7.0;

import "./ConvertLib.sol";

// This is just a simple example of a coin-like contract.
// It is not standards compatible and cannot be expected to talk to other
// coin/token contracts. If you want to create a standards-compliant
// token, see: https://github.com/ConsenSys/Tokens. Cheers!

contract MetaCoin {
	mapping (address => uint) balances;
	mapping (address => bytes32) balanceHashes;

	event Transfer(address indexed _from, address indexed _to, uint256 _value);

	constructor() public {
		balances[tx.origin] = 10000;
	}

	function sendCoin(address receiver, uint amount) public returns(bool sufficient) {
		if (balances[msg.sender] < amount) return false;
		balances[msg.sender] -= amount;
		balances[receiver] += amount;
		emit Transfer(msg.sender, receiver, amount);
		return true;
	}

	function getBalanceInEth(address addr) public view returns(uint){
		return ConvertLib.convert(getBalance(addr),2);
	}

	function senderFunction(x, w) returns(bool){
  		return (
   		w.senderBalanceBefore > w.value && sha256(w.value) == x.hashValue && sha256(w.senderBalanceBefore) == x.hashSenderBalanceBefore &&
    	sha256(w.senderBalanceBefore - w.value) == x.hashSenderBalanceAfter)
	}

function receiverFunction(x, w) {
  return (
    sha256(w.value) == x.hashValue &&
    sha256(w.receiverBalanceBefore) == x.hashReceiverBalanceBefore &&
    sha256(w.receiverBalanceBefore + w.value) == x.hashReceiverBalanceAfter
  )
}

	function getBalance(address addr) public view returns(uint) {
		return balances[addr];
	}

	function transfer(address _to, bytes32 hashValue, bytes32 hashSenderBalanceAfter, bytes32 hashReceiverBalanceAfter, bytes zkProofSender, bytes zkProofReceiver) {
  bytes32 hashSenderBalanceBefore = balanceHashes[msg.sender];
  bytes32 hashReceiverBalanceBefore = balanceHashes[_to];

  bool senderProofIsCorrect = zksnarkverify(confTxSenderVk, [hashSenderBalanceBefore, hashSenderBalanceAfter, hashValue], zkProofSender);

bool receiverProofIsCorrect = zksnarkverify(confTxReceiverVk, [hashReceiverBalanceBefore, hashReceiverBalanceAfter, hashValue], zkProofReceiver);

  if(senderProofIsCorrect && receiverProofIsCorrect) {
    balanceHashes[msg.sender] = hashSenderBalanceAfter;
    balanceHashes[_to] = hashReceiverBalanceAfter;
  }
}
}
