// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';

contract Watchain_PreSale is ReentrancyGuard, Context, Ownable {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  IERC20 private _token;

  address private _wallet;
  uint256 private _rate;
  uint256 private _weiRaised;

  uint256 public endICO;

  uint256 public minPurchase;
  uint256 public maxPurchase;
  uint256 public availableTokensICO;

  uint256 public softCap;
  uint256 public hardCap;

  mapping(address => bool) Claimed;
  mapping(address => uint256) CoinPaid;
  mapping(address => uint256) TokenBought;

  bool public presaleResult;

  event TokensPurchased(
    address indexed purchaser,
    address indexed beneficiary,
    uint256 value,
    uint256 amount
  );

  constructor(
    uint256 rate,
    address wallet,
    IERC20 token
  ) {
    require(rate > 0, 'Pre-Sale: rate is 0');
    require(wallet != address(0), 'Pre-Sale: wallet is the zero address');
    require(
      address(token) != address(0),
      'Pre-Sale: token is the zero address'
    );

    _rate = rate;
    _wallet = wallet;
    _token = token;
  }

  receive() external payable {
    if (endICO > 0 && block.timestamp < endICO) {
      buyTokens(_msgSender());
    } else {
      revert('Pre-Sale is closed');
    }
  }

  //Start Pre-Sale
  function startICO(
    uint256 endDate,
    uint256 _minPurchase,
    uint256 _maxPurchase,
    uint256 _availableTokens,
    uint256 _softCap,
    uint256 _hardCap
  ) external onlyOwner icoNotActive {
    require(endDate > block.timestamp, 'Pre-Sale: duration should be > 0');
    require(
      _availableTokens > 0 && _availableTokens <= _token.totalSupply(),
      'Pre-Sale: availableTokens should be > 0 and <= totalSupply'
    );
    require(_minPurchase > 0, 'Pre-Sale: _minPurchase should > 0');

    endICO = endDate;
    availableTokensICO = _availableTokens;

    minPurchase = _minPurchase;
    maxPurchase = _maxPurchase;

    softCap = _softCap;
    hardCap = _hardCap;
  }

  function stopICO() external onlyOwner icoActive {
    endICO = 0;

    if (_weiRaised > softCap) {
      presaleResult = true;
    } else {
      presaleResult = false;
    }
  }

  //Pre-Sale
  function buyTokens(address beneficiary)
    public
    payable
    nonReentrant
    icoActive
  {
    uint256 weiAmount = msg.value;
    _preValidatePurchase(beneficiary, weiAmount);
    uint256 tokens = _getTokenAmount(weiAmount);

    _weiRaised = _weiRaised.add(weiAmount);
    availableTokensICO = availableTokensICO - tokens;

    Claimed[beneficiary] = false;
    CoinPaid[beneficiary] = weiAmount;
    TokenBought[beneficiary] = tokens;

    emit TokensPurchased(_msgSender(), beneficiary, weiAmount, tokens);
  }

  function _preValidatePurchase(address beneficiary, uint256 weiAmount)
    internal
    view
  {
    require(
      beneficiary != address(0),
      'Pre-Sale: beneficiary is the zero address'
    );
    require(weiAmount != 0, 'Pre-Sale: weiAmount is 0');
    require(weiAmount >= minPurchase, 'have to send at least: minPurchase');
    require(weiAmount <= maxPurchase, 'have to send max: maxPurchase');

    this;
  }

  function claimToken(address beneficiary) public icoNotActive {
    require(
      Claimed[beneficiary] == false,
      'Pre-Sale: You did claim your tokens!'
    );
    Claimed[beneficiary] = true;

    _processPurchase(beneficiary, TokenBought[beneficiary]);
  }

  function claimRefund(address beneficiary) public icoNotActive {
    if (presaleResult == false) {
      require(
        Claimed[beneficiary] == false,
        'Pre-Sale: Only ICO member can refund coins!'
      );
      Claimed[beneficiary] = true;

      payable(beneficiary).transfer(CoinPaid[beneficiary]);
    }
  }

  function _deliverTokens(address beneficiary, uint256 tokenAmount) internal {
    _token.transfer(beneficiary, tokenAmount);
  }

  function _processPurchase(address beneficiary, uint256 tokenAmount) internal {
    _deliverTokens(beneficiary, tokenAmount);
  }

  function _getTokenAmount(uint256 weiAmount) internal view returns (uint256) {
    return weiAmount.mul(_rate).div(1000000);
  }

  function withdraw() external onlyOwner {
    require(address(this).balance > 0, 'Pre-Sale: Contract has no money');
    payable(_wallet).transfer(address(this).balance);
  }

  function getToken() public view returns (IERC20) {
    return _token;
  }

  function getWallet() public view returns (address) {
    return _wallet;
  }

  function getRate() public view returns (uint256) {
    return _rate;
  }

  function setRate(uint256 newRate) public onlyOwner {
    _rate = newRate;
  }

  function setAvailableTokens(uint256 amount) public onlyOwner {
    availableTokensICO = amount;
  }

  function weiRaised() public view returns (uint256) {
    return _weiRaised;
  }

  modifier icoActive() {
    require(
      endICO > 0 && block.timestamp < endICO && availableTokensICO > 0,
      'Pre-Sale: ICO must be active'
    );
    _;
  }

  modifier icoNotActive() {
    require(endICO < block.timestamp, 'Pre-Sale: ICO should not be active');
    _;
  }
}
