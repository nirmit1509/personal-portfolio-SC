// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

//***********************************************************************
//*                  **SynchroBitCoin Tokens**                          *
//*                    Name: SynchroBit                                 *
//*                      Symbol : SNB                                   *
//*               Total supply : 1,000,000,000 SNB                      *
//***********************************************************************

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';

contract SynchroBitCoin is IERC20 {
  using SafeMath for uint256;
  address public owner;
  string public name;
  string public symbol;
  uint8 public decimals;
  uint256 public totalSupply;
  bool public _lockStatus = false;
  uint256 public airdropcount = 0;

  mapping(address => uint256) private _balances;

  mapping(address => mapping(address => uint256)) private _allowed;

  mapping(address => uint256) private time;

  mapping(address => uint256) private _lockedAmount;

  constructor(
    string memory _name,
    string memory _symbol,
    uint8 _decimals,
    uint256 _totalSupply,
    address _owner
  ) {
    name = _name;
    symbol = _symbol;
    decimals = _decimals;
    totalSupply = _totalSupply * (10**uint256(decimals));
    _balances[owner] = _totalSupply;
    owner = _owner;
  }

  /*----------------------------------------------------------------------------
   * Functions for owner
   *----------------------------------------------------------------------------
   */

  /**
   * @dev modifier to check if the message sender is owner
   */
  modifier onlyOwner() {
    require(isOwner(), 'You are not authenticated to make this transfer');
    _;
  }

  /**
   * @dev Internal function for modifier
   */
  function isOwner() internal view returns (bool) {
    return msg.sender == owner;
  }

  /**
   * @dev Transfer ownership of the smart contract. For owner only
   * @param newOwner new contract owner address
   * @return request status
   */
  function transferOwnership(address newOwner)
    external
    onlyOwner
    returns (bool)
  {
    owner = newOwner;
    return true;
  }

  /* ----------------------------------------------------------------------------
   * Locking functions
   * ----------------------------------------------------------------------------
   */

  /**
   * @dev Lock all transfer functions of the contract
   * @param RunningStatusLock lock status for transfer functions
   * @return request status
   */
  function setAllTransfersLockStatus(bool RunningStatusLock)
    external
    onlyOwner
    returns (bool)
  {
    _lockStatus = RunningStatusLock;
    return true;
  }

  /**
   * @dev check lock status of all transfers
   * @return lock status
   */
  function getAllTransfersLockStatus() external view returns (bool) {
    return _lockStatus;
  }

  /**
   * @dev time calculator for locked tokens
   */
  function addLockingTime(
    address lockingAddress,
    uint256 lockingTime,
    uint256 amount
  ) internal returns (bool) {
    time[lockingAddress] = block.timestamp + (lockingTime * 1 days);
    _lockedAmount[lockingAddress] = _lockedAmount[lockingAddress].add(amount);
    return true;
  }

  /**
   * @dev check for time based lock
   * @param _address address to check for locking time
   * @return time in block format
   */
  function checkLockingTimeByAddress(address _address)
    external
    view
    returns (uint256)
  {
    return time[_address];
  }

  /**
   * @dev get amount of locked tokens by address
   * @param _address address to check for locking amount
   * @return amount in uint
   */
  function checkLockingAmountByAddress(address _address)
    external
    view
    returns (uint256)
  {
    if (block.timestamp < time[_address]) {
      return _lockedAmount[_address];
    } else {
      return 0;
    }
  }

  /**
   * @dev return locking status
   * @param userAddress address of to check
   * @return locking status in true or false
   */
  function getLockingStatus(address userAddress) external view returns (bool) {
    if (block.timestamp < time[userAddress]) {
      return true;
    } else {
      return false;
    }
  }

  /**
   * @dev  Decreaese locking time
   * @param _affectiveAddress Address of the locked address
   * @param _decreasedTime Time in days to be affected
   */
  function decreaseLockingTimeByAddress(
    address _affectiveAddress,
    uint256 _decreasedTime
  ) external onlyOwner returns (bool) {
    require(
      _decreasedTime > 0 && time[_affectiveAddress] > block.timestamp,
      'Please check address status or Incorrect input'
    );
    time[_affectiveAddress] =
      time[_affectiveAddress] -
      (_decreasedTime * 1 days);
    return true;
  }

  /**
   * @dev Increase locking time
   * @param _affectiveAddress Address of the locked address
   * @param _increasedTime Time in days to be affected
   */
  function increaseLockingTimeByAddress(
    address _affectiveAddress,
    uint256 _increasedTime
  ) external onlyOwner returns (bool) {
    require(
      _increasedTime > 0 && time[_affectiveAddress] > block.timestamp,
      'Please check address status or Incorrect input'
    );
    time[_affectiveAddress] =
      time[_affectiveAddress] +
      (_increasedTime * 1 days);
    return true;
  }

  /**
   * @dev modifier to check validation of lock status of smart contract
   */
  modifier AllTransfersLockStatus() {
    require(
      _lockStatus == false,
      'All transactions are locked for this contract'
    );
    _;
  }

  /**
   * @dev modifier to check locking amount
   * @param _address address to check
   * @param requestedAmount Amount to check
   */
  modifier checkLocking(address _address, uint256 requestedAmount) {
    if (block.timestamp <= time[_address]) {
      require(
        !(_balances[_address].sub(_lockedAmount[_address]) < requestedAmount),
        'Insufficient unlocked balance'
      );
    }
    _;
  }

  /* ----------------------------------------------------------------------------
   * View only functions
   * ----------------------------------------------------------------------------
   */

  /**
   * @dev Gets the balance of the specified address.
   * @param _owner The address to query the balance of.
   * @return A uint256 representing the amount owned by the passed address.
   */
  function balanceOf(address _owner) public view returns (uint256) {
    return _balances[_owner];
  }

  /**
   * @dev Function to check the amount of tokens that an owner allowed to a spender.
   * @param _owner address The address which owns the funds.
   * @param spender address The address which will spend the funds.
   * @return A uint256 specifying the amount of tokens still available for the spender.
   */
  function allowance(address _owner, address spender)
    public
    view
    returns (uint256)
  {
    return _allowed[_owner][spender];
  }

  /* ----------------------------------------------------------------------------
   * Transfer, allow, mint and burn functions
   * ----------------------------------------------------------------------------
   */

  /**
   * @dev Transfer token to a specified address.
   * @param to The address to transfer to.
   * @param value The amount to be transferred.
   */
  function transfer(address to, uint256 value)
    public
    AllTransfersLockStatus
    checkLocking(msg.sender, value)
    returns (bool)
  {
    _transfer(msg.sender, to, value);
    return true;
  }

  /**
   * @dev Transfer tokens from one address to another.
   * Note that while this function emits an Approval event, this is not required as per the specification,
   * and other compliant implementations may not emit the event.
   * @param from address The address which you want to send tokens from
   * @param to address The address which you want to transfer to
   * @param value uint256 the amount of tokens to be transferred
   */
  function transferFrom(
    address from,
    address to,
    uint256 value
  ) public AllTransfersLockStatus checkLocking(from, value) returns (bool) {
    _transfer(from, to, value);
    _approve(from, msg.sender, _allowed[from][msg.sender].sub(value));
    return true;
  }

  /**
   * @dev Transfer tokens to a specified address (For Only Owner)
   * @param to The address to transfer to.
   * @param value The amount to be transferred.
   * @return Transfer status in true or false
   */
  function transferByOwner(
    address to,
    uint256 value,
    uint256 lockingTime
  ) public AllTransfersLockStatus onlyOwner returns (bool) {
    addLockingTime(to, lockingTime, value);
    _transfer(msg.sender, to, value);
    return true;
  }

  /**
   * @dev withdraw locked tokens only (For Only Owner)
   * @param from locked address
   * @param to address to transfer tokens
   * @param value amount of tokens to unlock and transfer
   * @return transfer status
   */
  function transferLockedTokens(
    address from,
    address to,
    uint256 value
  ) external onlyOwner returns (bool) {
    require(
      (_lockedAmount[from] >= value) && (block.timestamp < time[from]),
      'Insufficient unlocked balance'
    );
    require(from != address(0) && to != address(0), 'Invalid address');
    _lockedAmount[from] = _lockedAmount[from] - value;
    _transfer(from, to, value);
    return true;
  }

  /**
   * @dev Airdrop function to airdrop tokens. Best works upto 50 addresses in one time. Maximum limit is 200 addresses in one time.
   * @param _addresses array of address in serial order
   * @param _amount amount in serial order with respect to address array
   */
  function airdropByOwner(address[] memory _addresses, uint256[] memory _amount)
    public
    AllTransfersLockStatus
    onlyOwner
    returns (bool)
  {
    require(_addresses.length == _amount.length, 'Invalid Array');
    uint256 count = _addresses.length;
    for (uint256 i = 0; i < count; i++) {
      _transfer(msg.sender, _addresses[i], _amount[i]);
      airdropcount = airdropcount + 1;
    }
    return true;
  }

  /**
   * @dev Transfer token for a specified addresses.
   * @param from The address to transfer from.
   * @param to The address to transfer to.
   * @param value The amount to be transferred.
   */
  function _transfer(
    address from,
    address to,
    uint256 value
  ) internal {
    require(to != address(0), 'Invalid to address');
    _balances[from] = _balances[from].sub(value);
    _balances[to] = _balances[to].add(value);
    emit Transfer(from, to, value);
  }

  /**
   * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
   * Beware that changing an allowance with this method brings the risk that someone may use both the old
   * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
   * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   * @param spender The address which will spend the funds.
   * @param value The amount of tokens to be spent.
   */
  function approve(address spender, uint256 value) public returns (bool) {
    _approve(msg.sender, spender, value);
    return true;
  }

  /**
   * @dev Approve an address to spend another addresses' tokens.
   * @param _owner The address that owns the tokens.
   * @param spender The address that will spend the tokens.
   * @param value The number of tokens that can be spent.
   */
  function _approve(
    address _owner,
    address spender,
    uint256 value
  ) internal {
    require(spender != address(0), 'Invalid address');
    require(_owner != address(0), 'Invalid address');
    _allowed[_owner][spender] = value;
    emit Approval(_owner, spender, value);
  }

  /**
   * @dev Increase the amount of tokens that an owner allowed to a spender.
   * approve should be called when _allowed[msg.sender][spender] == 0. To increment
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   * Emits an Approval event.
   * @param spender The address which will spend the funds.
   * @param addedValue The amount of tokens to increase the allowance by.
   */
  function increaseAllowance(address spender, uint256 addedValue)
    public
    returns (bool)
  {
    _approve(
      msg.sender,
      spender,
      _allowed[msg.sender][spender].add(addedValue)
    );
    return true;
  }

  /**
   * @dev Decrease the amount of tokens that an owner allowed to a spender.
   * approve should be called when _allowed[msg.sender][spender] == 0. To decrement
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   * Emits an Approval event.
   * @param spender The address which will spend the funds.
   * @param subtractedValue The amount of tokens to decrease the allowance by.
   */
  function decreaseAllowance(address spender, uint256 subtractedValue)
    public
    returns (bool)
  {
    _approve(
      msg.sender,
      spender,
      _allowed[msg.sender][spender].sub(subtractedValue)
    );
    return true;
  }

  /**
   * @dev Internal function that burns an amount of the token of a given
   * account.
   * @param account The account whose tokens will be burnt.
   * @param value The amount that will be burnt.
   */
  function _burn(address account, uint256 value) internal {
    require(account != address(0), 'Invalid account');
    totalSupply = totalSupply.sub(value);
    _balances[account] = _balances[account].sub(value);
    emit Transfer(account, address(0), value);
  }

  /**
   * @dev Burns a specific amount of tokens.
   * @param value The amount of token to be burned.
   */
  function burn(uint256 value)
    public
    onlyOwner
    checkLocking(msg.sender, value)
  {
    _burn(msg.sender, value);
  }

  /**
   * @dev Function that mints an amount of the token and assigns it to
   * a given address. This modify the the balance such that the
   * proper events are emitted. This function is restricted to only owner of the contract
   * @param account The account that will receive the created tokens.
   * @param value The amount that will be created.
   */
  function mint(address account, uint256 value) external onlyOwner {
    require(account != address(0));
    totalSupply = totalSupply.add(value);
    _balances[account] = _balances[account].add(value);
    emit Transfer(address(0), account, value);
  }
}
