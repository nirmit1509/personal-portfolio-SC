// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';

interface ITokenManager {
  function castVote(
    address creator,
    address owner,
    address voter,
    uint8 response
  ) external;

  function sendToken(
    address tokenOwner,
    address from,
    address to,
    uint256 amount
  ) external;

  function transferPower(address account) external;
}

contract NFTVideo is ERC721URIStorage, Ownable {
  using SafeMath for uint256;

  struct Video {
    string tokenURI;
    uint256 numberOfQuestions;
  }

  struct Question {
    string[] questionHash;
    int256[] rank; // upvote-downvote
  }

  struct Bid {
    address bidder;
    uint256 amount;
  }

  string private _name = 'Video';
  string private _symbol = 'VID';
  uint256 private _totalSupply;
  uint256 private _nextTokenId = 1000;

  ITokenManager tokenManager;

  mapping(uint256 => Question) private _ranks;
  mapping(uint256 => Video) private _tokenDetails;

  mapping(uint256 => address) private _videoCreator;

  mapping(address => mapping(string => int256)) private _votingPower;
  mapping(uint256 => mapping(string => mapping(address => int256)))
    private _voteResponse; //0-> not voted 1-> upvoted 2-> downvoted

  // Auction
  mapping(uint256 => uint256) private _biddingTime;
  mapping(uint256 => Bid) private _maxBid;

  modifier biddingEnabled(uint256 tokenId) {
    require(block.timestamp < _biddingTime[tokenId], 'bidding time is over!');
    _;
  }

  constructor(address _tokenManager) ERC721(_name, _symbol) Ownable() {
    tokenManager = ITokenManager(_tokenManager);
  }

  function setTokenManager(address _tokenManager) external {
    tokenManager = ITokenManager(_tokenManager);
  }

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
  function mint(string memory tokenURI) external {
    _mint(_msgSender(), _nextTokenId);
    _setTokenURI(_nextTokenId, tokenURI);
    Video memory video = Video(tokenURI, 0);
    _tokenDetails[_nextTokenId] = video;
    _videoCreator[_nextTokenId] = _msgSender();
    _biddingTime[_nextTokenId] = 0;

    _nextTokenId = _nextTokenId.add(1);
    _totalSupply = _totalSupply.add(1);
  }

  function burn(address owner, uint256 tokenId) external onlyOwner {
    require(ownerOf(tokenId) == owner, 'given address is not owner of Token');
    _burn(tokenId);
  }

  function addQuestion(uint256 tokenId, string memory questionHash) external {
    require(_exists(tokenId), 'tokenId does not exists');
    Video memory video = _tokenDetails[tokenId];
    uint256 questionCount = video.numberOfQuestions;

    // Question memory question = Question(questionHash, 0);
    _ranks[tokenId].questionHash.push(questionHash);
    _ranks[tokenId].rank.push(0);

    video.numberOfQuestions = questionCount.add(1);
    _tokenDetails[tokenId] = video;
  }

  function getAllQuestion(uint256 tokenId)
    external
    view
    returns (uint256, string[] memory)
  {
    require(_exists(tokenId), 'tokenId does not exists');
    uint256 questionCount = _tokenDetails[tokenId].numberOfQuestions;
    return (questionCount, _ranks[tokenId].questionHash);
  }

  function getRank(uint256 tokenId, string memory questionHash)
    external
    view
    returns (int256)
  {
    require(_exists(tokenId), 'tokenId does not exists');
    uint256 questionId = getQuestionID(tokenId, questionHash);

    return _ranks[tokenId].rank[questionId];
  }

  function transferVotingPower(string memory hash, address to)
    external
    returns (bool)
  {
    require(
      _votingPower[_msgSender()][hash] != -1,
      'caller has already voted or transfered power'
    );
    _votingPower[to][hash] =
      _votingPower[to][hash] +
      _votingPower[_msgSender()][hash];
    _votingPower[_msgSender()][hash] = -1;
    tokenManager.transferPower(_msgSender());

    return true;
  }

  function getVotingPower(string memory hash, address voter)
    external
    view
    returns (int256)
  {
    return _votingPower[voter][hash];
  }

  function upvote(uint256 tokenId, string memory questionHash) external {
    require(_exists(tokenId), 'tokenId does not exists');

    uint256 questionId = getQuestionID(tokenId, questionHash);
    require(
      _voteResponse[tokenId][questionHash][_msgSender()] == 0,
      'Voter has already voted'
    );

    int256 power = _votingPower[_msgSender()][questionHash];
    require(
      power != -1,
      'Voter has already transfered voting power for that hash'
    );

    address creator = _videoCreator[tokenId];
    address videoOwner = ownerOf(tokenId);

    tokenManager.castVote(creator, videoOwner, _msgSender(), 1);

    // Question memory question = _ranks[tokenId][questionId];
    // question.rank = question.rank.add(1);
    _ranks[tokenId].rank[questionId] =
      _ranks[tokenId].rank[questionId] +
      (power + 1);

    // Vote memory vote = Vote(_msgSender(),1);
    _voteResponse[tokenId][questionHash][_msgSender()] = power + 1;

    _votingPower[_msgSender()][questionHash] = -1;
  }

  function downvote(uint256 tokenId, string memory questionHash) external {
    require(_exists(tokenId), 'tokenId does not exists');

    uint256 questionId = getQuestionID(tokenId, questionHash);
    require(
      _voteResponse[tokenId][questionHash][_msgSender()] == 0,
      'Voter has already voted'
    );

    int256 power = _votingPower[_msgSender()][questionHash];
    require(
      power != -1,
      'Voter has already transfered voting power for that hash'
    );

    address creator = _videoCreator[tokenId];
    address videoOwner = ownerOf(tokenId);

    tokenManager.castVote(creator, videoOwner, _msgSender(), 2);
    // Question memory question = _ranks[tokenId][questionId];
    // question.rank = question.rank.sub(1);
    // _ranks[tokenId][questionId] = question;

    // Vote memory vote = Vote(_msgSender(),1);
    _ranks[tokenId].rank[questionId] =
      _ranks[tokenId].rank[questionId] -
      (power + 1);

    _voteResponse[tokenId][questionHash][_msgSender()] = int256(power + 1);

    _votingPower[_msgSender()][questionHash] = -1;
  }

  function clearVote(uint256 tokenId, string memory questionHash) external {
    require(_exists(tokenId), 'tokenId does not exists');

    uint256 questionId = getQuestionID(tokenId, questionHash);
    int256 response = _voteResponse[tokenId][questionHash][_msgSender()];

    require(response != 0, 'Voter has not voted yet');

    // Question memory question = _ranks[tokenId][questionId];
    if (response > 0) {
      _ranks[tokenId].rank[questionId] =
        _ranks[tokenId].rank[questionId] -
        response;
      _votingPower[_msgSender()][questionHash] =
        _votingPower[_msgSender()][questionHash] +
        response;
    } else {
      _ranks[tokenId].rank[questionId] =
        _ranks[tokenId].rank[questionId] +
        response;
      _votingPower[_msgSender()][questionHash] =
        _votingPower[_msgSender()][questionHash] -
        response;
    }

    _voteResponse[tokenId][questionHash][_msgSender()] = 0;

    // _ranks[tokenId][questionId] = question;
  }

  function getVoterResponse(
    uint256 tokenId,
    string memory questionHash,
    address voter
  ) external view returns (int256) {
    require(_exists(tokenId), 'tokenId does not exists');
    require(_exists(tokenId, questionHash), 'question does not exists');
    return _voteResponse[tokenId][questionHash][voter];
  }

  function getQuestionID(uint256 tokenId, string memory questionHash)
    internal
    view
    returns (uint256)
  {
    uint256 questionCount = _tokenDetails[tokenId].numberOfQuestions;

    for (uint256 i = 0; i < questionCount; i++) {
      if (
        keccak256(bytes(_ranks[tokenId].questionHash[i])) ==
        keccak256(bytes(questionHash))
      ) {
        return i;
      }
    }
    revert('question hash does not found');
  }

  function _exists(uint256 tokenId, string memory questionHash)
    internal
    view
    returns (bool)
  {
    uint256 questionCount = _tokenDetails[tokenId].numberOfQuestions;

    for (uint256 i = 0; i < questionCount; i++) {
      if (
        keccak256(bytes(_ranks[tokenId].questionHash[i])) ==
        keccak256(bytes(questionHash))
      ) {
        return true;
      }
    }
    return false;
  }

  //////////////////////////////////////////////
  //            Auction                    /////
  //////////////////////////////////////////////

  function startAuction(
    uint256 tokenId,
    uint256 startBid,
    uint256 AuctionTime
  ) external {
    require(
      _msgSender() == ownerOf(tokenId),
      'Video: Caller is not owner of NFT'
    );
    require(_biddingTime[tokenId] == 0, 'NFT is already placed for Auction');

    Bid memory bid = Bid(ownerOf(tokenId), startBid);
    _maxBid[tokenId] = bid;

    _biddingTime[tokenId] = block.timestamp + AuctionTime;
  }

  function highestBid(uint256 tokenId) external view returns (uint256) {
    require(_exists(tokenId), ' Video: query for nonexistent token');
    return _maxBid[tokenId].amount;
  }

  function maxBidder(uint256 tokenId) external view returns (address) {
    require(_exists(tokenId), ' Video: query for nonexistent token');
    return _maxBid[tokenId].bidder;
  }

  function biddingTimeRemaining(uint256 tokenId)
    external
    view
    returns (uint256)
  {
    require(_exists(tokenId), ' Video: query for nonexistent token');
    if (block.timestamp < _biddingTime[tokenId]) {
      return _biddingTime[tokenId] - block.timestamp;
    } else {
      return 0;
    }
  }

  function placeBid(uint256 tokenId, uint256 amount)
    external
    biddingEnabled(tokenId)
  {
    Bid memory maxBid = _maxBid[tokenId];
    uint256 maxAmount = maxBid.amount;

    require(amount > maxAmount, 'Bidding price is less than highest bid');
    maxBid.bidder = _msgSender();
    maxBid.amount = amount;

    _maxBid[tokenId] = maxBid;

    // emit BidPlaced(_msgSender(),tokenId,amount);
  }

  function claim(uint256 tokenId) external {
    require(_biddingTime[tokenId] != 0, 'Video: token is not for Auction');
    require(
      _biddingTime[tokenId] < block.timestamp,
      'bidding is still goining'
    );
    require(
      _maxBid[tokenId].bidder == _msgSender(),
      'caller is not the highest bidder'
    );
    address creator = _videoCreator[tokenId];
    uint256 amount = _maxBid[tokenId].amount;
    // require(amount <= msg.value, "msg.Value is less than bid placed");
    tokenManager.sendToken(creator, _msgSender(), ownerOf(tokenId), amount);
    _transfer(ownerOf(tokenId), _msgSender(), tokenId);
    _biddingTime[tokenId] = 0;
  }
}
