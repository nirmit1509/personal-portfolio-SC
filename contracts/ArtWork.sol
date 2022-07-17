/**
 * https://www.notion.so/NFT-ArtWork-Documentation-bf51034b24c34a7a9330fbff73211891
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';

contract ArtWork is ERC721URIStorage, Ownable {
  using SafeMath for uint256;

  struct Bid {
    address bidder;
    uint256 amount;
  }

  struct Art {
    string category;
    string media;
    string size;
  }

  string private _name = 'ArtWork';
  string private _symbol = 'ART';
  uint256 private _totalSupply;
  uint256 private _nextTokenId = 1000;
  mapping(uint256 => uint256) private _biddingTime;
  mapping(uint256 => Bid) private _maxBid;
  mapping(uint256 => Art) private _tokenDetails;

  event BidPlaced(address indexed bidder, uint256 tokenId, uint256 amount);

  event Claimed(address indexed newOwner, uint256 tokenId, uint256 amount);

  modifier biddingEnabled(uint256 tokenId) {
    require(block.timestamp < _biddingTime[tokenId], 'bidding time is over!');
    _;
  }

  constructor() ERC721(_name, _symbol) Ownable() {}

  /// @dev Returns the total number of tokens (minted - burned) registered
  function totalSupply() external view returns (uint256) {
    return _totalSupply;
  }

  /// @dev Returns the token id of the next minted token
  function nextTokenId() external view returns (uint256) {
    return _nextTokenId;
  }

  /// @dev Mint a token. Only "owner" may call this function.
  /// @param tokenURI The tokenURI of the the tokenURI
  function mint(
    string memory tokenURI,
    uint256 startingBidValue,
    uint256 bidTimeInSeconds,
    string memory category,
    string memory media,
    string memory size
  ) external onlyOwner {
    _mint(owner(), _nextTokenId);
    _setTokenURI(_nextTokenId, tokenURI);
    Art memory art = Art(category, media, size);
    _tokenDetails[_nextTokenId] = art;

    Bid memory startBid = Bid(owner(), startingBidValue);
    _maxBid[_nextTokenId] = startBid;
    _biddingTime[_nextTokenId] = block.timestamp + bidTimeInSeconds;
    _nextTokenId = _nextTokenId.add(1);
    _totalSupply = _totalSupply.add(1);
  }

  function burn(address owner, uint256 tokenId) external onlyOwner {
    require(ownerOf(tokenId) == owner, 'given address is not owner of Token');
    _burn(tokenId);
  }

  function getCategory(uint256 tokenId) external view returns (string memory) {
    require(_exists(tokenId), ' ArtWork: query for nonexistent token');
    return _tokenDetails[tokenId].category;
  }

  function getMedia(uint256 tokenId) external view returns (string memory) {
    require(_exists(tokenId), ' ArtWork: query for nonexistent token');
    return _tokenDetails[tokenId].media;
  }

  function getSize(uint256 tokenId) external view returns (string memory) {
    require(_exists(tokenId), ' ArtWork: query for nonexistent token');
    return _tokenDetails[tokenId].size;
  }

  function highestBid(uint256 tokenId) external view returns (uint256) {
    require(_exists(tokenId), ' ArtWork: query for nonexistent token');
    return _maxBid[tokenId].amount;
  }

  function maxBidder(uint256 tokenId) external view returns (address) {
    require(_exists(tokenId), ' ArtWork: query for nonexistent token');
    return _maxBid[tokenId].bidder;
  }

  function biddingTimeRemaining(uint256 tokenId)
    external
    view
    returns (uint256)
  {
    require(_exists(tokenId), ' ArtWork: query for nonexistent token');
    if (block.timestamp < _biddingTime[tokenId]) {
      return _biddingTime[tokenId] - block.timestamp;
    } else {
      return 0;
    }
  }

  function bid(uint256 tokenId, uint256 amount)
    external
    biddingEnabled(tokenId)
  {
    Bid memory maxBid = _maxBid[tokenId];
    uint256 maxAmount = maxBid.amount;

    require(amount > maxAmount, 'Bidding price is less than highest bid');
    maxBid.bidder = _msgSender();
    maxBid.amount = amount;

    _maxBid[tokenId] = maxBid;

    emit BidPlaced(_msgSender(), tokenId, amount);
  }

  function claim(uint256 tokenId) external payable {
    require(
      _biddingTime[tokenId] < block.timestamp,
      'bidding is still goining'
    );
    require(
      _maxBid[tokenId].bidder == _msgSender(),
      'caller is not the highest bidder'
    );

    uint256 amount = _maxBid[tokenId].amount;
    require(amount <= msg.value, 'msg.Value is less than bid placed');

    _transfer(owner(), _msgSender(), tokenId);

    emit Claimed(_msgSender(), tokenId, amount);
  }

  function contractBalance() external view returns (uint256) {
    return address(this).balance;
  }

  function redeemBalance() external onlyOwner {
    payable(owner()).transfer(address(this).balance);
  }
}
