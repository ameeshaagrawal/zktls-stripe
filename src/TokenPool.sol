// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "solmate/utils/SafeTransferLib.sol";
import "socket-protocol/contracts/base/PlugBase.sol";
import "socket-protocol/contracts/utils/AccessControl.sol";
import "socket-protocol/contracts/utils/RescueFundsLib.sol";

import {RESCUE_ROLE} from "socket-protocol/contracts/utils/common/AccessRoles.sol";
import {ETH_ADDRESS} from "socket-protocol/contracts/utils/common/Constants.sol";

interface ITokenPool {
    function transfer(
        bytes32 transferId_,
        address token_,
        uint256 amount_,
        address receiver_
    ) external;
}

/// @title TokenPool
/// @notice Contract for managing token deposits and withdrawals
contract TokenPool is PlugBase, Ownable {
    mapping(address => uint256) public balanceOf;
    mapping(bytes32 => bool) public transferExecuted;

    error InsufficientTokenBalance(address token_);
    error InvalidDepositAmount();
    error InvalidTokenAddress();
    error TransferAlreadyExecuted(bytes32 transferId);
    error InvalidTokenAddress();

    event TokenDeposited(address token, uint256 amount);
    event TokenWithdrawn(address token, uint256 amount);
    event TokenTransferred(
        bytes32 transferId,
        address token,
        uint256 amount,
        address receiver
    );

    constructor(address owner_) {
        _initializeOwner(owner_);
    }

    /// @notice Deposits tokens into the pool
    /// @param token_ The token address (use ETH_ADDRESS for ETH)
    /// @param amount_ The amount to deposit
    function deposit(
        address token_,
        uint256 amount_
    ) external payable onlyOwner {
        if (token_ == ETH_ADDRESS) {
            if (msg.value != amount_) revert InvalidDepositAmount();
        } else {
            if (token_.code.length == 0) revert InvalidTokenAddress();
            SafeTransferLib.safeTransferFrom(
                ERC20(token_),
                msg.sender,
                address(this),
                amount_
            );
        }

        balanceOf[token_] += amount_;
        emit TokenDeposited(token_, amount_);
    }

    /// @notice Withdraws tokens from the pool
    /// @param token_ The token address (use ETH_ADDRESS for ETH)
    /// @param amount_ The amount to withdraw
    function withdraw(address token_, uint256 amount_) external onlyOwner {
        if (balanceOf[token_] < amount_)
            revert InsufficientTokenBalance(token_);

        balanceOf[token_] -= amount_;

        if (token_ == ETH_ADDRESS) {
            SafeTransferLib.safeTransferETH(payable(msg.sender), amount_);
        } else {
            SafeTransferLib.safeTransfer(ERC20(token_), msg.sender, amount_);
        }

        emit TokenWithdrawn(token_, amount_);
    }

    /// @notice Transfers tokens to a receiver
    /// @param transferId_ Unique identifier for this transfer
    /// @param token_ The token address (use ETH_ADDRESS for ETH)
    /// @param amount_ The amount to transfer
    /// @param receiver_ The address to receive tokens
    function transfer(
        bytes32 transferId_,
        address token_,
        uint256 amount_,
        address receiver_
    ) external onlySocket {
        if (transferExecuted[transferId_])
            revert TransferAlreadyExecuted(transferId_);
        if (balanceOf[token_] < amount_)
            revert InsufficientTokenBalance(token_);

        transferExecuted[transferId_] = true;
        balanceOf[token_] -= amount_;

        if (token_ == ETH_ADDRESS) {
            SafeTransferLib.safeTransferETH(payable(receiver_), amount_);
        } else {
            SafeTransferLib.safeTransfer(ERC20(token_), receiver_, amount_);
        }

        emit TokenTransferred(transferId_, token_, amount_, receiver_);
    }

    function connectSocket(
        address appGateway_,
        address socket_,
        address switchboard_
    ) external onlyOwner {
        _connectSocket(appGateway_, socket_, switchboard_);
    }

    /**
     * @notice Rescues funds from the contract if they are locked by mistake
     * @param token_ The address of the token contract
     * @param rescueTo_ The address where rescued tokens need to be sent
     * @param amount_ The amount of tokens to be rescued
     */
    function rescueFunds(
        address token_,
        address rescueTo_,
        uint256 amount_
    ) external onlyRole(RESCUE_ROLE) {
        RescueFundsLib._rescueFunds(token_, rescueTo_, amount_);
    }

    fallback() external payable {}

    receive() external payable {}
}
