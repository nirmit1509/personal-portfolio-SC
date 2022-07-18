// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface vault {
  function transferamount(
    uint256 amount,
    address _recipient,
    address token
  ) external returns (bool);

  function reserve(address token) external view returns (uint256);
}

contract Catoshi is IERC20, Ownable {
  using SafeMath for uint256;

  string private _name;
  string private _symbol;
  uint8 private _decimals = 18;

  uint256 private _processedFees = 1000000000000000; //estimated gas fees
  address public _bridgeFeesAddress =
    address(0xD378dBeD86689D0dBA19Ca2bab322B6f23765288);

  mapping(address => mapping(address => uint256)) private _allowances;
  mapping(address => uint256) private _balances;

  mapping(uint256 => bool) private nonceProcessed;
  uint256 _nonce = 0;

  uint256 private _totalSupply = 21 * 10**6 * 10**18; // 21 M tokens minted initially

  uint256 private _mintFee = 1;

  address system;

  vault public _bscTokenVault;

  uint256 public airdropcount = 0;

  uint256 private curTime;

  event SwapRequest(address to, uint256 amount, uint256 nonce);

  modifier onlySystem() {
    require(system == _msgSender(), 'Ownable: caller is not the system');
    _;
  }

  constructor(
    string memory cats_name,
    string memory cats_symbol,
    address _system
  ) {
    _name = cats_name;
    _symbol = cats_symbol;
    curTime = block.timestamp;
    system = _system;
    _balances[_msgSender()] = _totalSupply;
  }

  function name() public view returns (string memory) {
    return _name;
  }

  function symbol() public view returns (string memory) {
    return _symbol;
  }

  function decimals() public view returns (uint8) {
    return _decimals;
  }

  function totalSupply() public view override returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address account) public view override returns (uint256) {
    return _balances[account];
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
        'ERC20: transfer amount exceeds allowance'
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
        'ERC20: decreased allowance below zero'
      )
    );
    return true;
  }

  function setSystem(address _system) external onlyOwner {
    system = _system;
  }

  function setBSCVaultaddress(address _add) public onlyOwner returns (bool) {
    require(_add != address(0), 'Invalid Address');
    _bscTokenVault = vault(_add);
    return true;
  }

  function _approve(
    address owner,
    address spender,
    uint256 amount
  ) private {
    require(owner != address(0), 'ERC20: approve from the zero address');
    require(spender != address(0), 'ERC20: approve to the zero address');
    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }

  function _transfer(
    address sender,
    address recipient,
    uint256 amount
  ) private {
    require(sender != address(0), 'ERC20: transfer from the zero address');
    require(recipient != address(0), 'ERC20: transfer to the zero address');
    require(amount > 0, 'Transfer amount must be greater than zero');
    _balances[sender] = _balances[sender].sub(amount);
    _balances[recipient] = _balances[recipient].add(amount);
    emit Transfer(sender, recipient, amount);
  }

  function setBridgeFeesAddress(address bridgeFeesAddress) external onlyOwner {
    _bridgeFeesAddress = bridgeFeesAddress;
  }

  function setProcessedFees(uint256 processedFees) external onlyOwner {
    _processedFees = processedFees;
  }

  function getProcessedFees() external view returns (uint256) {
    return _processedFees;
  }

  function setSwapFee(uint256 mintFee) public onlyOwner returns (bool) {
    _mintFee = mintFee;
    return true;
  }

  /**
   * @dev Function for getting rewards percentage by owner
   */
  function getSwapFee() public view returns (uint256) {
    return _mintFee;
  }

  function getSwapStatus(uint256 nonce) external view returns (bool) {
    return nonceProcessed[nonce];
  }

  /**
   * @dev Airdrop function to airdrop tokens. Best works upto 50 addresses in one time. Maximum limit is 200 addresses in one time.
   * @param _addresses array of address in serial order
   * @param _amount amount in serial order with respect to address array
   */
  function airdropByOwner(address[] memory _addresses, uint256[] memory _amount)
    public
    onlyOwner
    returns (bool)
  {
    require(_addresses.length == _amount.length, 'Invalid Array');
    uint256 count = _addresses.length;
    for (uint256 i = 0; i < count; i++) {
      _transfer(_msgSender(), _addresses[i], _amount[i]);
      airdropcount = airdropcount + 1;
    }
    return true;
  }

  function swap(uint256 amount) external payable {
    require(msg.value >= _processedFees, 'Insufficient processed fees');
    require(
      _balances[_msgSender()] >= amount,
      'You do not have sufficient tokens to swap'
    );
    _nonce = _nonce.add(1);
    _transfer(_msgSender(), address(_bscTokenVault), amount);
    emit SwapRequest(_msgSender(), amount, _nonce);
  }

  function feeCalculation(uint256 amount) public view returns (uint256) {
    uint256 _amountAfterFee = (amount - (amount.mul(_mintFee) / 1000));
    return _amountAfterFee;
  }

  function swapBack(
    address to,
    uint256 amount,
    uint256 nonce,
    address _czats,
    uint256 _deadline
  ) external onlySystem {
    require(!nonceProcessed[nonce], 'swap already processed');
    require(
      block.timestamp <= _deadline,
      'ERROR: Deadline for this transaction has passed.'
    );
    uint256 temp = feeCalculation(amount);
    uint256 bridgeFees = amount.sub(temp);
    _bscTokenVault.transferamount(temp, to, _czats);
    _bscTokenVault.transferamount(bridgeFees, _bridgeFeesAddress, _czats);
    nonceProcessed[nonce] = true;
  }

  function withdrawBNB(uint256 amount, address receiver) external onlyOwner {
    require(amount <= address(this).balance, 'amount exceeds contract balance');
    payable(receiver).transfer(amount);
  }
}
