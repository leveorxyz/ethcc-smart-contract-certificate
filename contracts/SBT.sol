// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/draft-ERC721Votes.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract SBT is ERC721, Ownable, EIP712, ERC721Votes {
    using Counters for Counters.Counter;
    mapping (uint => status) tokenStatus;
    mapping (address => bool) isVerifier;
    mapping (uint => address) verifier;
    uint256[] private revokedList;

    enum status {
        NOT_VERIFIED,
        VERIFIED,
        REVOKED
    }

    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("SBToken", "SBT") EIP712("SBToken", "1") {}

    function _baseURI() internal pure override returns (string memory) {
        return "https://www.myapp.com/";
    }

    function safeMint(address to) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        tokenStatus[tokenId] = status.NOT_VERIFIED;
    }

    // The following functions are overrides required by Solidity.

    function _afterTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Votes)
    {
        super._afterTokenTransfer(from, to, tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
    internal override(ERC721)
    {
        require(from == address(0), "Err: token is SOUL BOUND");
        super._beforeTokenTransfer(from, to, tokenId);
    }

    modifier notRevoked (uint256 tokenId) {
        require(tokenStatus[tokenId] < status.REVOKED, "The token is already revoked");
        _;
    }

    modifier onlyExistingToken (uint tokenId) {
        require (tokenId <= _tokenIdCounter.current(), "Invalid token id");
        _;
    }

    modifier onlyVerifier (uint tokenId) {
        require (verifier[tokenId] == msg.sender || msg.sender == owner(), "Only the verifier can revoke");
        _;
    }

    modifier ifVerifier {
        require(isVerifier[msg.sender] || msg.sender == owner(), "Only verifiers allowed");
        _;
    }

    function makeVerifier(address _address) external onlyOwner {
        isVerifier[_address] = true;
    }

    function verify (uint tokenId) external ifVerifier onlyExistingToken(tokenId) notRevoked(tokenId) {
        tokenStatus[tokenId] = status.VERIFIED;
        verifier[tokenId] = msg.sender;
    }

    function revoke(uint256 tokenId) external onlyExistingToken(tokenId) notRevoked(tokenId) onlyVerifier(tokenId) {
        tokenStatus[tokenId] = status.REVOKED;
        revokedList.push(tokenId);
    }

    function getRevokedTokens() external view returns(uint256[] memory) {
        return revokedList;
    }

}