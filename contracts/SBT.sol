// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/draft-ERC721Votes.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract SBT is ERC721, Ownable, EIP712, ERC721Votes {
    using Counters for Counters.Counter;
    mapping(uint256 => status) tokenStatus;
    mapping(uint256 => address) issuer;
    mapping(address => bool) isIssuer;
    mapping(address => bool) isVerifier;
    mapping(uint256 => address) verifier;
    mapping(uint256 => MetaData) metaData;
    mapping(address => uint256) nIssued;
    uint256[] private revokedList;
    enum status {
        NOT_VERIFIED,
        VERIFIED,
        REVOKED
    }
    struct MetaData {
        uint256 id;
        string certificateName;
        string userName;
        status verificationStatus;
        string description;
        uint256 issuedAt;
        string signature;
        string uri;
    }
    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("SBToken", "SBT") EIP712("SBToken", "1") {}

    function _baseURI() internal pure override returns (string memory) {
        return "https://www.myapp.com/";
    }

    function safeMint(
        address to,
        string memory _certificateName,
        string memory _userName,
        string memory _description,
        uint256 _issuedAt,
        string memory _signature,
        string memory _tokenUri
    ) public ifIssuer {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        tokenStatus[tokenId] = status.NOT_VERIFIED;
        issuer[tokenId] = msg.sender;
        nIssued[msg.sender]++;
        metaData[tokenId] = MetaData({
            id: tokenId,
            certificateName: _certificateName,
            userName: _userName,
            verificationStatus: status.NOT_VERIFIED,
            description: _description,
            issuedAt: _issuedAt,
            signature: _signature,
            uri: string(abi.encodePacked(_baseURI(), _tokenUri))
        });
    }

    // The following functions are overrides required by Solidity.

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Votes) {
        super._afterTokenTransfer(from, to, tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721) {
        require(from == address(0), "Err: token is SOUL BOUND");
        super._beforeTokenTransfer(from, to, tokenId);
    }

    modifier onlyIssuer(uint256 tokenId) {
        require(issuer[tokenId] == msg.sender, "Only the verifier can revoke");
        _;
    }

    modifier ifIssuer() {
        require(isIssuer[msg.sender], "Only issuers allowed");
        _;
    }
    modifier onlyVerifier() {
        require(isVerifier[msg.sender], "Only verifiers allowed");
        _;
    }

    function makeVerifier(address _address) external onlyOwner {
        isVerifier[_address] = true;
    }

    function makeIssuer(address _address) external onlyOwner {
        isIssuer[_address] = true;
    }

    function verify(uint256 tokenId)
        external
        onlyVerifier
    {
        tokenStatus[tokenId] = status.VERIFIED;
        verifier[tokenId] = msg.sender;
        metaData[tokenId].verificationStatus = status.VERIFIED;
    }

    function revoke(uint256 tokenId)
        external
        onlyIssuer(tokenId)
    {
        tokenStatus[tokenId] = status.REVOKED;
        revokedList.push(tokenId);
    }

    function getTokenPublicData(uint256 tokenId)
        external
        view
        returns (MetaData memory)
    {
        return metaData[tokenId];
    }

    function getIssuedTokens(uint256 mode)
        external
        view
        returns (MetaData[] memory)
    {
        uint256 counter = 0;
        uint256 totalTokens = _tokenIdCounter.current();
        if (mode == 0) {
            totalTokens = nIssued[msg.sender];
        } else if (mode == 2) {
            uint256 ownedCount = 0;
            for (uint256 i=0; i<totalTokens; i++) {
                ownedCount += ownerOf(i) == msg.sender ? 1 : 0;
            }
            totalTokens = ownedCount;
        }
        MetaData[] memory tokenList = new MetaData[](totalTokens);
        for (uint256 i = 0; i < totalTokens; i++) {
            if ((mode == 0 && issuer[i] == msg.sender) || (mode == 1) || (mode == 2 && ownerOf(i) == msg.sender)) {
                tokenList[counter] = metaData[i];
                counter++;
            }
        }
        return tokenList;
    }

    function getRevokedTokens() external view returns (uint256[] memory) {
        return revokedList;
    }
}
