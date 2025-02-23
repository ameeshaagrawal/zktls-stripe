// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "socket-protocol/contracts/base/AppDeployerBase.sol";
import "socket-protocol/contracts/interfaces/IForwarder.sol";
import "socket-protocol/contracts/interfaces/IPromise.sol";
import "./TokenPool.sol";

contract CheckoutAppGateway is AppDeployerBase {
    address public arbReclaimAddress =
        address(0x4D1ee04EB5CeE02d4C123d4b67a86bDc7cA2E62A);
    address public optReclaimAddress =
        address(0x47dC7a593A857f906f19dE09c44DedCdC02Dc991);

    uint256 constant txIdCounter = 1;

    bytes32 public tokenPool = _createContractId("tokenPool");
    bytes32 public paymentVerifier = _createContractId("paymentVerifier");

    constructor(
        address addressResolver_,
        address deployerContract_,
        address auctionManager_,
        Fees memory fees_,
        address reclaimAddress_
    ) AppDeployerBase(addressResolver_, auctionManager_) {
        addressResolver__.setContractsToGateways(deployerContract_);
        _setOverrides(fees_);
    }

    function deploy() public {
        _deploy(tokenPool, 421614, IsPlug.YES);
        _deploy(tokenPool, 11155420, IsPlug.YES);

        _deploy(paymentVerifier, 421614, IsPlug.YES);
        _deploy(paymentVerifier, 11155420, IsPlug.YES);
    }

    function initialize(uint32) public pure override {
        return;
    }

    function checkout(
        address tokenPool_,
        uint256 amount_,
        MerkleProof memory proof_
    ) external async {
        uint256 txId_ = txIdCounter++;
        bytes32 asyncId = getCurrentAsyncId();

        // verify merkle proof
        IPaymentVerifier(arbForwarderAddress).verifyProofAndReleaseFunds(
            txId_,
            proof_
        );

        IPromise(arbForwarderAddress).then(
            abi.encodeWithSelector(
                ITokenPool.isProofVerified.selector,
                txId_,
                asyncId
            )
        );

        // transfer tokens
        ITokenPool(tokenPool_).transfer(txId_, amount_);
    }

    function isProofVerified(uint256 txId_, bytes32 asyncId_) external {
        deliveryHelper().cancelTransaction(asyncId_);
    }

    function setFees(Fees memory fees_) public {
        fees = fees_;
    }

    function withdrawFeeTokens(
        uint32 chainSlug_,
        address token_,
        uint256 amount_,
        address receiver_
    ) external {
        _withdrawFeeTokens(chainSlug_, token_, amount_, receiver_);
    }
}
