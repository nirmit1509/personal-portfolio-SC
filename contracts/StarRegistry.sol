// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';

contract ApolloSpaceToken is Context, IERC20, Ownable {
  using SafeMath for uint256;
  using Address for address;

  mapping(address => uint256) private _rOwned;
  mapping(address => uint256) private _tOwned;
  mapping(address => mapping(address => uint256)) private _allowances;

  mapping(address => bool) private _isExcluded;
  address[] private _excluded;

  string private _NAME = 'Apollo Space Token';
  string private _SYMBOL = 'AST';
  uint8 private _DECIMALS = 9;

  uint256 private constant _MAX = ~uint256(0);
  uint256 private _DECIMALFACTOR = 10**uint256(_DECIMALS);
  uint256 private constant _GRANULARITY = 100;

  uint256 private _tTotal = 13000000000 * _DECIMALFACTOR;
  uint256 private _rTotal = (_MAX - (_MAX % _tTotal));

  uint256 private _tFeeTotal;
  uint256 private _tBurnTotal;

  uint256 private _TAX_FEE = 500;
  uint256 private _BURN_FEE = 200;
  uint256 private _MAX_TX_SIZE = 13000000000 * _DECIMALFACTOR;

  constructor() {
    _rOwned[_msgSender()] = _rTotal;
    emit Transfer(address(0), _msgSender(), _tTotal);
  }

  function name() public view returns (string memory) {
    return _NAME;
  }

  function symbol() public view returns (string memory) {
    return _SYMBOL;
  }

  function decimals() public view returns (uint8) {
    return _DECIMALS;
  }

  function totalSupply() public view override returns (uint256) {
    return _tTotal;
  }

  function balanceOf(address account) public view override returns (uint256) {
    if (_isExcluded[account]) return _tOwned[account];
    return tokenFromReflection(_rOwned[account]);
  }

  function transfer(address recipient, uint256 amount)
    public
    override
    returns (bool)
  {
    _transfer(_msgSender(), recipient, amount);
    return true;
  }

  function allowance(address owner, address spender)
    public
    view
    override
    returns (uint256)
  {
    return _allowances[owner][spender];
  }

  function approve(address spender, uint256 amount)
    public
    override
    returns (bool)
  {
    _approve(_msgSender(), spender, amount);
    return true;
  }

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) public override returns (bool) {
    _transfer(sender, recipient, amount);
    _approve(
      sender,
      _msgSender(),
      _allowances[sender][_msgSender()].sub(
        amount,
        'BEP20: transfer amount exceeds allowance'
      )
    );
    return true;
  }

  function increaseAllowance(address spender, uint256 addedValue)
    public
    virtual
    returns (bool)
  {
    _approve(
      _msgSender(),
      spender,
      _allowances[_msgSender()][spender].add(addedValue)
    );
    return true;
  }

  function decreaseAllowance(address spender, uint256 subtractedValue)
    public
    virtual
    returns (bool)
  {
    _approve(
      _msgSender(),
      spender,
      _allowances[_msgSender()][spender].sub(
        subtractedValue,
        'BEP20: decreased allowance below zero'
      )
    );
    return true;
  }

  function isExcluded(address account) public view returns (bool) {
    return _isExcluded[account];
  }

  function totalFees() public view returns (uint256) {
    return _tFeeTotal;
  }

  function totalBurn() public view returns (uint256) {
    return _tBurnTotal;
  }

  function deliver(uint256 tAmount) public {
    address sender = _msgSender();
    require(
      !_isExcluded[sender],
      'Excluded addresses cannot call this function'
    );
    (uint256 rAmount, , , , , ) = _getValues(tAmount);
    _rOwned[sender] = _rOwned[sender].sub(rAmount);
    _rTotal = _rTotal.sub(rAmount);
    _tFeeTotal = _tFeeTotal.add(tAmount);
  }

  function reflectionFromToken(uint256 tAmount, bool deductTransferFee)
    public
    view
    returns (uint256)
  {
    require(tAmount <= _tTotal, 'Amount must be less than supply');
    if (!deductTransferFee) {
      (uint256 rAmount, , , , , ) = _getValues(tAmount);
      return rAmount;
    } else {
      (, uint256 rTransferAmount, , , , ) = _getValues(tAmount);
      return rTransferAmount;
    }
  }

  function tokenFromReflection(uint256 rAmount) public view returns (uint256) {
    require(rAmount <= _rTotal, 'Amount must be less than total reflections');
    uint256 currentRate = _getRate();
    return rAmount.div(currentRate);
  }

  function excludeAccount(address account) external onlyOwner {
    require(
      account != 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D,
      'We can not exclude Uniswap router.'
    );
    require(!_isExcluded[account], 'Account is already excluded');
    if (_rOwned[account] > 0) {
      _tOwned[account] = tokenFromReflection(_rOwned[account]);
    }
    _isExcluded[account] = true;
    _excluded.push(account);
  }

  function includeAccount(address account) external onlyOwner {
    require(_isExcluded[account], 'Account is already excluded');
    for (uint256 i = 0; i < _excluded.length; i++) {
      if (_excluded[i] == account) {
        _excluded[i] = _excluded[_excluded.length - 1];
        _tOwned[account] = 0;
        _isExcluded[account] = false;
        _excluded.pop();
        break;
      }
    }
  }

  function _approve(
    address owner,
    address spender,
    uint256 amount
  ) private {
    require(owner != address(0), 'BEP20: approve from the zero address');
    require(spender != address(0), 'BEP20: approve to the zero address');

    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }

  function _transfer(
    address sender,
    address recipient,
    uint256 amount
  ) private {
    require(sender != address(0), 'BEP20: transfer from the zero address');
    require(recipient != address(0), 'BEP20: transfer to the zero address');
    require(amount > 0, 'Transfer amount must be greater than zero');

    if (sender != owner() && recipient != owner())
      require(
        amount <= _MAX_TX_SIZE,
        'Transfer amount exceeds the maxTxAmount.'
      );

    if (_isExcluded[sender] && !_isExcluded[recipient]) {
      _transferFromExcluded(sender, recipient, amount);
    } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
      _transferToExcluded(sender, recipient, amount);
    } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
      _transferStandard(sender, recipient, amount);
    } else if (_isExcluded[sender] && _isExcluded[recipient]) {
      _transferBothExcluded(sender, recipient, amount);
    } else {
      _transferStandard(sender, recipient, amount);
    }
  }

  function _transferStandard(
    address sender,
    address recipient,
    uint256 tAmount
  ) private {
    uint256 currentRate = _getRate();
    (
      uint256 rAmount,
      uint256 rTransferAmount,
      uint256 rFee,
      uint256 tTransferAmount,
      uint256 tFee,
      uint256 tBurn
    ) = _getValues(tAmount);
    uint256 rBurn = tBurn.mul(currentRate);
    _rOwned[sender] = _rOwned[sender].sub(rAmount);
    _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
    _reflectFee(rFee, rBurn, tFee, tBurn);
    emit Transfer(sender, recipient, tTransferAmount);
  }

  function _transferToExcluded(
    address sender,
    address recipient,
    uint256 tAmount
  ) private {
    uint256 currentRate = _getRate();
    (
      uint256 rAmount,
      uint256 rTransferAmount,
      uint256 rFee,
      uint256 tTransferAmount,
      uint256 tFee,
      uint256 tBurn
    ) = _getValues(tAmount);
    uint256 rBurn = tBurn.mul(currentRate);
    _rOwned[sender] = _rOwned[sender].sub(rAmount);
    _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
    _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
    _reflectFee(rFee, rBurn, tFee, tBurn);
    emit Transfer(sender, recipient, tTransferAmount);
  }

  function _transferFromExcluded(
    address sender,
    address recipient,
    uint256 tAmount
  ) private {
    uint256 currentRate = _getRate();
    (
      uint256 rAmount,
      uint256 rTransferAmount,
      uint256 rFee,
      uint256 tTransferAmount,
      uint256 tFee,
      uint256 tBurn
    ) = _getValues(tAmount);
    uint256 rBurn = tBurn.mul(currentRate);
    _tOwned[sender] = _tOwned[sender].sub(tAmount);
    _rOwned[sender] = _rOwned[sender].sub(rAmount);
    _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
    _reflectFee(rFee, rBurn, tFee, tBurn);
    emit Transfer(sender, recipient, tTransferAmount);
  }

  function _transferBothExcluded(
    address sender,
    address recipient,
    uint256 tAmount
  ) private {
    uint256 currentRate = _getRate();
    (
      uint256 rAmount,
      uint256 rTransferAmount,
      uint256 rFee,
      uint256 tTransferAmount,
      uint256 tFee,
      uint256 tBurn
    ) = _getValues(tAmount);
    uint256 rBurn = tBurn.mul(currentRate);
    _tOwned[sender] = _tOwned[sender].sub(tAmount);
    _rOwned[sender] = _rOwned[sender].sub(rAmount);
    _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
    _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
    _reflectFee(rFee, rBurn, tFee, tBurn);
    emit Transfer(sender, recipient, tTransferAmount);
  }

  function _reflectFee(
    uint256 rFee,
    uint256 rBurn,
    uint256 tFee,
    uint256 tBurn
  ) private {
    _rTotal = _rTotal.sub(rFee).sub(rBurn);
    _tFeeTotal = _tFeeTotal.add(tFee);
    _tBurnTotal = _tBurnTotal.add(tBurn);
    _tTotal = _tTotal.sub(tBurn);
  }

  function setMaxTxPercent(uint256 maxTxPercent, uint256 maxTxDecimals)
    external
    onlyOwner
  {
    _MAX_TX_SIZE = _tTotal.mul(maxTxPercent).div(
      10**(uint256(maxTxDecimals) + 2)
    );
  }

  function _getValues(uint256 tAmount)
    private
    view
    returns (
      uint256,
      uint256,
      uint256,
      uint256,
      uint256,
      uint256
    )
  {
    (uint256 tTransferAmount, uint256 tFee, uint256 tBurn) = _getTValues(
      tAmount,
      _TAX_FEE,
      _BURN_FEE
    );
    uint256 currentRate = _getRate();
    (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(
      tAmount,
      tFee,
      tBurn,
      currentRate
    );
    return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tBurn);
  }

  function _getTValues(
    uint256 tAmount,
    uint256 taxFee,
    uint256 burnFee
  )
    private
    pure
    returns (
      uint256,
      uint256,
      uint256
    )
  {
    uint256 tFee = ((tAmount.mul(taxFee)).div(_GRANULARITY)).div(100);
    uint256 tBurn = ((tAmount.mul(burnFee)).div(_GRANULARITY)).div(100);
    uint256 tTransferAmount = tAmount.sub(tFee).sub(tBurn);
    return (tTransferAmount, tFee, tBurn);
  }

  function _getRValues(
    uint256 tAmount,
    uint256 tFee,
    uint256 tBurn,
    uint256 currentRate
  )
    private
    pure
    returns (
      uint256,
      uint256,
      uint256
    )
  {
    uint256 rAmount = tAmount.mul(currentRate);
    uint256 rFee = tFee.mul(currentRate);
    uint256 rBurn = tBurn.mul(currentRate);
    uint256 rTransferAmount = rAmount.sub(rFee).sub(rBurn);
    return (rAmount, rTransferAmount, rFee);
  }

  function _getRate() private view returns (uint256) {
    (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
    return rSupply.div(tSupply);
  }

  function _getCurrentSupply() private view returns (uint256, uint256) {
    uint256 rSupply = _rTotal;
    uint256 tSupply = _tTotal;
    for (uint256 i = 0; i < _excluded.length; i++) {
      if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply)
        return (_rTotal, _tTotal);
      rSupply = rSupply.sub(_rOwned[_excluded[i]]);
      tSupply = tSupply.sub(_tOwned[_excluded[i]]);
    }
    if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
    return (rSupply, tSupply);
  }

  function _getTaxFee() private view returns (uint256) {
    return _TAX_FEE;
  }

  function _getMaxTxAmount() private view returns (uint256) {
    return _MAX_TX_SIZE;
  }

  function TAXFEE(uint256 taxFee) external onlyOwner {
    _TAX_FEE = taxFee;
  }

  function BURNFEE(uint256 burnFee) external onlyOwner {
    _BURN_FEE = burnFee;
  }

  function burn(uint256 amount) public {
    _burn(_msgSender(), amount);
  }

  function _burn(address account, uint256 amount) internal {
    require(account != address(0), 'BEP20: burn from the zero address');
    _rOwned[account] = _rOwned[account].sub(
      amount,
      'BEP20: burn amount exceeds balance'
    );
    _tTotal = _tTotal.sub(amount);
    emit Transfer(account, address(0), amount);
  }

  function _burnFrom(address account, uint256 amount) internal {
    _burn(account, amount);
    _approve(
      account,
      _msgSender(),
      _allowances[account][_msgSender()].sub(
        amount,
        'BEP20: burn amount exceeds allowance'
      )
    );
  }
}

contract StarRegistry is
  ERC721Upgradeable,
  OwnableUpgradeable,
  ReentrancyGuardUpgradeable
{
  address public tokenAddress;

  uint256 public ownerCutAST;
  uint256 public totalSupply = 0;

  uint256 public creatorCutAST;

  mapping(uint256 => address) public tokenCreators;

  mapping(uint256 => uint256) public tokenPriceinWEI;

  mapping(uint256 => uint256) private highestCurrentBid;

  mapping(uint256 => address) public highestBidder;

  mapping(address => bool) private approvedMinters;

  mapping(uint256 => uint256) public createdTime;

  mapping(uint256 => uint256) public bidTimeLimit;

  using SafeMathUpgradeable for uint256;

  function initialize(
    address _ASTaddress,
    uint256 ownerCut,
    uint256 CCcut
  ) public initializer {
    OwnableUpgradeable.__Ownable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
    ERC721Upgradeable.__ERC721_init('Star registry', 'STR');
    tokenAddress = _ASTaddress;
    ownerCutAST = ownerCut;
    creatorCutAST = CCcut;
  }

  function changePaymentToken(address _tokenAddress) public {
    require(msg.sender == owner());
    tokenAddress = _tokenAddress;
  }

  function Burn(uint256 id) public {
    require(msg.sender == owner() || msg.sender == ownerOf(id));
    _burn(id);
  }

  function setOwner(address newOwner) public {
    require(msg.sender == owner());
    transferOwnership(newOwner);
  }

  function setOwnerCutandCreatorCut(
    uint256 ownerCutpercent,
    uint256 creatorCutPercent
  ) public {
    require(msg.sender == owner());
    ownerCutAST = ownerCutpercent; //percentage
    creatorCutAST = creatorCutPercent;
  }

  function approveMinter(address minter) public {
    require(msg.sender == owner());
    approvedMinters[minter] = true;
  }

  function createNFT(uint256 price) public {
    require(
      msg.sender == owner() || approvedMinters[msg.sender] == true,
      'Not approved Minter'
    );
    uint256 id = totalSupply + 1;
    _safeMint(msg.sender, id);
    tokenPriceinWEI[id] = price;
    tokenCreators[id] = msg.sender;
  }

  function getSaleStatus(uint256 id) public view returns (bool) {
    if (getApproved(id) == address(this)) {
      return true;
    } else return false;
  }

  function bid(uint256 id, uint256 bidAmt) public nonReentrant {
    require(
      ApolloSpaceToken(tokenAddress).balanceOf(msg.sender) >= bidAmt,
      'Low AST balance to bid'
    );
    require(getSaleStatus(id) == true);
    require(
      block.timestamp - createdTime[id] < bidTimeLimit[id],
      'Cannot Bid,Auction Time over'
    );
    require(msg.sender != ownerOf(id), 'Token owner cannot bid');
    if (bidAmt > highestCurrentBid[id]) {
      highestCurrentBid[id] = bidAmt;
      highestBidder[id] = msg.sender;
    } else {
      revert();
    }
  }

  function setNewPrice(uint256 id, uint256 amt) public nonReentrant {
    require(msg.sender == ownerOf(id));
    require(!getSaleStatus(id));
    tokenPriceinWEI[id] = amt;
  }

  function placeSellorder(uint256 id, uint256 timeInDays) public {
    require(_exists(id));
    require(ownerOf(id) == msg.sender);
    super.approve(address(this), id);
    createdTime[id] = block.timestamp;
    bidTimeLimit[id] = SafeMathUpgradeable.mul(timeInDays, 86400);
  }

  function buy(uint256 id) external nonReentrant {
    require(_exists(id));
    require(
      getSaleStatus(id) == true,
      'token not approved for sale on this market'
    );
    uint256 Ocut = ceilDiv(tokenPriceinWEI[id] * ownerCutAST, 100);
    uint256 Ccut = ceilDiv(tokenPriceinWEI[id] * creatorCutAST, 100);
    ApolloSpaceToken(tokenAddress).transferFrom(msg.sender, owner(), Ocut);
    ApolloSpaceToken(tokenAddress).transferFrom(
      msg.sender,
      tokenCreators[id],
      Ccut
    );
    ApolloSpaceToken(tokenAddress).transferFrom(
      msg.sender,
      ownerOf(id),
      tokenPriceinWEI[id] - Ocut - Ccut
    );
    IERC721Upgradeable(address(this)).safeTransferFrom(
      ownerOf(id),
      msg.sender,
      id
    );
  }

  function acceptBid(uint256 id) external nonReentrant {
    require(
      block.timestamp - createdTime[id] < bidTimeLimit[id],
      'cannot Accept bid,Time Limit over'
    );
    require(msg.sender == ownerOf(id));
    uint256 Ocut = ceilDiv(tokenPriceinWEI[id] * ownerCutAST, 100);
    uint256 Ccut = ceilDiv(tokenPriceinWEI[id] * creatorCutAST, 100);
    ApolloSpaceToken(tokenAddress).transferFrom(
      highestBidder[id],
      owner(),
      Ocut
    );
    ApolloSpaceToken(tokenAddress).transferFrom(
      highestBidder[id],
      tokenCreators[id],
      Ccut
    );
    ApolloSpaceToken(tokenAddress).transferFrom(
      highestBidder[id],
      ownerOf(id),
      tokenPriceinWEI[id] - Ocut - Ccut
    );
    safeTransferFrom(ownerOf(id), highestBidder[id], id);
  }

  /**
   * @dev Returns the ceiling of the division of two numbers.
   *
   * This differs from standard division with `/` in that it rounds up instead
   * of rounding down.
   */
  function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
    // (a + b - 1) / b can overflow on addition, so we distribute.
    return a / b + (a % b == 0 ? 0 : 1);
  }
}
