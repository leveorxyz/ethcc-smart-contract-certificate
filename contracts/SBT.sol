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
        string certificateName;
        string userName;
        string topic;
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
        string memory _topic,
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
            certificateName: _certificateName,
            userName: _userName,
            topic: _topic,
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

    modifier notRevoked(uint256 tokenId) {
        require(
            tokenStatus[tokenId] < status.REVOKED,
            "The token is already revoked"
        );
        _;
    }

    modifier onlyExistingToken(uint256 tokenId) {
        require(tokenId <= _tokenIdCounter.current(), "Invalid token id");
        _;
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
    modifier permissionMetadata(uint256 tokenId) {
        require(
            isVerifier[msg.sender] ||
                isIssuer[msg.sender] ||
                ownerOf(tokenId) == msg.sender,
            "Unauthorized"
        );
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
        onlyExistingToken(tokenId)
        notRevoked(tokenId)
    {
        tokenStatus[tokenId] = status.VERIFIED;
        verifier[tokenId] = msg.sender;
    }

    function revoke(uint256 tokenId)
        external
        onlyExistingToken(tokenId)
        notRevoked(tokenId)
        onlyIssuer(tokenId)
    {
        tokenStatus[tokenId] = status.REVOKED;
        revokedList.push(tokenId);
    }

    function getTokenPublicData(uint256 tokenId)
        external
        view
        onlyExistingToken(tokenId)
        returns (MetaData memory)
    {
        return metaData[tokenId];
    }

    function getIssuedTokens()
        external
        view
        ifIssuer
        returns (MetaData[] memory)
    {
        uint256 counter = 0;
        uint256 totalTokens = _tokenIdCounter.current();
        MetaData[] memory tokenList = new MetaData[](nIssued[msg.sender]);
        for (uint256 i = 0; i < totalTokens; i++) {
            if (issuer[i] == msg.sender) {
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
