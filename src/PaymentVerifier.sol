// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@reclaimprotocol/reclaim-solidity-sdk/contracts/IReclaim.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PaymentVerifier is Ownable {
    IReclaim public reclaimContract;
    uint256 private constant externalNullifier =
        2440356218280977251650924410834269003129361313211160658678024373945754528348;
    uint256 private constant dappId =
        0xa05be1ad5952483191c8ae5e0f0d56b81a677cf55ac15041f6acabd13201fb95;

    struct MerkleProof {
        string provider;
        uint256 merkleTreeRoot;
        uint256 signal;
        uint256 nullifierHash;
        uint256[8] proof;
    }

    // Mapping to track verified payments
    mapping(uint256 => bool) public hasVerifiedPayment;

    // Events
    event PaymentVerified(address indexed user, bytes32 indexed claimId);

    constructor(address _reclaimContractAddress) {
        reclaimContract = IReclaim(_reclaimContractAddress);
    }

    function verifyProofAndReleaseFunds(
        uint256 txId_,
        MerkleProof memory proof_
    ) external onlySocket {
        // Verify that user hasn't already claimed
        require(!hasVerifiedPayment[txId_], "Payment already verified");

        // Verify the merkle proof
        _verifyMerkleProof(proof_);

        // Mark payment as verified
        hasVerifiedPayment[txId_] = true;

        // Emit event
        emit PaymentVerified(txId_, bytes32(proof_.merkleTreeRoot));
    }

    function _verifyMerkleProof(MerkleProof memory proof_) internal {
        require(
            Reclaim.verifyMerkelIdentity(
                proof_.provider,
                proof_.merkleTreeRoot,
                proof_.signal,
                proof_.nullifierHash,
                externalNullifier,
                dappId,
                proof_.proof
            ),
            "Proof not valid"
        );
    }

    // Function to check if a user has verified payment
    function isPaymentVerified(address user) external view returns (bool) {
        return hasVerifiedPayment[user];
    }
}
