// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract NFTSTORE is ERC721URIStorage {
    address payable public marketplaceOwner;
    uint256 public listingFeePercent = 20;
    uint256 private currentTokenId;
    uint256 private totalItemsSold;

    struct NFTListing {
        uint256 tokenId;
        address payable owner;
        address payable seller;
        uint256 price;
        bool isListed;
        uint256 totalFractions;
        uint256 fractionsAvailable;
    }

    struct FractionOwnership {
        uint256 tokenId;
        uint256 fractionsOwned;
    }

    mapping (uint256 => NFTListing) private tokenIdToListing;
    mapping (address => FractionOwnership[]) private userFractions;

    modifier onlyOwner {
        require(msg.sender == marketplaceOwner, "Only owner can call this function");
        _;
    }

    constructor() ERC721("NFTSTORE", "NFTS") {
        marketplaceOwner = payable(msg.sender);
    }

    function updateListingFeePercent(uint256 _listingFeePercent) public onlyOwner {
        listingFeePercent = _listingFeePercent;
    }

    function getListingFeePercent() public view returns (uint256) {
        return listingFeePercent;
    }

    function getCurrentTokenId() public view returns(uint256) {
        return currentTokenId;
    }

    function getNFTListing(uint256 _tokenId) public view returns(NFTListing memory) {
        return tokenIdToListing[_tokenId];
    }

    function createToken(string memory _tokenURI, uint256 _price, uint256 _totalFractions) public returns(uint256) {
        require(_price > 0, "Price must be greater than zero");
        require(_totalFractions > 0, "Total fractions must be greater than zero");

        currentTokenId++;
        uint256 newTokenId = currentTokenId;
        _safeMint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, _tokenURI);

        _createNFTListing(newTokenId, _price, _totalFractions);

        return newTokenId;
    }

    function _createNFTListing(uint256 _tokenId, uint256 _price, uint256 _totalFractions) private {
        tokenIdToListing[_tokenId] = NFTListing({
            tokenId: _tokenId,
            owner: payable(msg.sender),
            seller: payable(msg.sender),
            price: _price,
            isListed: true,
            totalFractions: _totalFractions,
            fractionsAvailable: _totalFractions
        });

        userFractions[msg.sender].push(FractionOwnership({
            tokenId: _tokenId,
            fractionsOwned: _totalFractions
        }));
    }

    function executeFractionalSale(uint256 tokenId, uint256 fractions) public payable {
        NFTListing storage listing = tokenIdToListing[tokenId];
        uint256 pricePerFraction = listing.price / listing.totalFractions;
        uint256 totalPrice = pricePerFraction * fractions;
        address payable seller = listing.seller;

        require(fractions <= listing.fractionsAvailable, "Not enough fractions available");
        require(msg.value == totalPrice, "Please submit the correct price to complete the purchase");

        listing.fractionsAvailable -= fractions;

        bool found = false;
        for (uint256 i = 0; i < userFractions[msg.sender].length; i++) {
            if (userFractions[msg.sender][i].tokenId == tokenId) {
                userFractions[msg.sender][i].fractionsOwned += fractions;
                found = true;
                break;
            }
        }
        if (!found) {
            userFractions[msg.sender].push(FractionOwnership({
                tokenId: tokenId,
                fractionsOwned: fractions
            }));
        }

        uint256 listingFee = (totalPrice * listingFeePercent) / 100;
        marketplaceOwner.transfer(listingFee);
        seller.transfer(msg.value - listingFee);
    }

    function getMyFractionalNFTs() public view returns(FractionOwnership[] memory) {
        return userFractions[msg.sender];
    }

    function getAllListedNFTs() public view returns (NFTListing[] memory) {
        uint256 totalNFTCount = currentTokenId;
        uint256 listedCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalNFTCount; i++) {
            if (tokenIdToListing[i + 1].isListed) {
                listedCount++;
            }
        }

        NFTListing[] memory listedNFTs = new NFTListing[](listedCount);
        for (uint256 i = 0; i < totalNFTCount; i++) {
            if (tokenIdToListing[i + 1].isListed) {
                uint256 tokenId = i + 1;
                NFTListing storage listing = tokenIdToListing[tokenId];
                listedNFTs[currentIndex] = listing;
                currentIndex += 1;
            }
        }

        return listedNFTs;
    }

    function getMyNFTs() public view returns(NFTListing[] memory) {
        uint256 totalNFTCount = currentTokenId;
        uint256 myNFTCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalNFTCount; i++) {
            if (tokenIdToListing[i + 1].owner == msg.sender || tokenIdToListing[i + 1].seller == msg.sender) {
                myNFTCount++;
            }
        }

        NFTListing[] memory myNFTs = new NFTListing[](myNFTCount);
        for (uint256 i = 0; i < totalNFTCount; i++) {
            if (tokenIdToListing[i + 1].owner == msg.sender || tokenIdToListing[i + 1].seller == msg.sender) {
                uint256 tokenId = i + 1;
                NFTListing storage listing = tokenIdToListing[tokenId];
                myNFTs[currentIndex] = listing;
                currentIndex++;
            }
        }

        return myNFTs;
    }
}