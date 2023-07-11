// SPDX-License-Identifier: MIT
    
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";



contract MultiSigWallet is Ownable {
    error OwnersNumberMustBeGreaterThanOne(uint256 ownersNum);
    error ConfirmationsNumNotInSyncWithOwnersNum(uint256 confirmationsNum, uint256 ownersNum);
    error InvalidAddress(address addr);
    error TransferAmountMustBeGreaterThanZero(uint256 transferAmount);
    error InvalidTransactionId(uint transactionId);
    error TransactionAlreadyConfirmed(uint transactionId);
    error TransactionAlreadyExecuted(uint transactionId);
    error TransactionFailed(uint transactionId);

    address[] public owners;
    uint public numConfirmationsRequired;

    modifier noZeroAddress(address _addr) {
        if(_addr == address(0))
            revert InvalidAddress(_addr);
        _;
    }

    struct Transaction {
        address to;
        uint256 value;
        bool executed;
    }

    mapping(uint256 => mapping(address => bool)) isConfirmed;
    Transaction[] public transactions;

    event TransactionSubmitted(uint256 transactionId, address sender, address receiver, uint256 amount);
    event TransactionConfirmed(uint256 transactionId);
    event TransactionExecuted(uint transactionId);

    constructor(address[] memory _owners, uint256 _numConfirmationsRequired) {
        if(_owners.length < 2)
            revert OwnersNumberMustBeGreaterThanOne(_owners.length);
        if(_numConfirmationsRequired > _owners.length)
            revert ConfirmationsNumNotInSyncWithOwnersNum(_numConfirmationsRequired, _owners.length);
        
        // Overflow not possible: i < _owners.length
        unchecked {
            for(uint256 i = 0;i < _owners.length;i++) {
                if(_owners[i] == address(0))
                    revert InvalidAddress(address(0));
                owners.push(_owners[i]);
            }
        }
        numConfirmationsRequired = _numConfirmationsRequired;
    }

    function submitTransaction(address _to) public payable noZeroAddress(_to) {
        if(msg.value <= 0)
            revert TransferAmountMustBeGreaterThanZero(msg.value);
        
        uint256 transactionId = transactions.length;

        transactions.push(Transaction(_to, msg.value, false));

        emit TransactionSubmitted(transactionId, msg.sender, _to, msg.value);
    }

    function confirmTransaction(uint _transactionId) public {
        if(_transactionId > transactions.length)
            revert InvalidTransactionId(_transactionId);
        if(isConfirmed[_transactionId][msg.sender])
            revert TransactionAlreadyConfirmed(_transactionId);
        
        isConfirmed[_transactionId][msg.sender] = true;
        emit TransactionConfirmed(_transactionId);
        
        if(isTransactionConfirmed(_transactionId)) {
            executeTransaction(_transactionId);
        }
    }

    function executeTransaction(uint _transactionId) public payable {
        if(_transactionId > transactions.length)
            revert InvalidTransactionId(_transactionId);
        if(transactions[_transactionId].executed)
            revert TransactionAlreadyExecuted(_transactionId);

        (bool success,) = transactions[_transactionId].to.call{value: transactions[_transactionId].value}("");

        if(!success)
            revert TransactionFailed(_transactionId);
        
        transactions[_transactionId].executed = true;
        emit TransactionExecuted(_transactionId);
    }

    function isTransactionConfirmed(uint _transactionId) internal view returns(bool) {
        if(_transactionId > transactions.length)
            revert InvalidTransactionId(_transactionId);
        
        uint confirmationCount;

        // Overflow not possible: i < owners.length
        unchecked {
            for(uint i = 0;i < owners.length;i++) {
                if(isConfirmed[_transactionId][owners[i]]) {
                    confirmationCount++;
                }
            }
        }

        return confirmationCount >= numConfirmationsRequired;
    }

}