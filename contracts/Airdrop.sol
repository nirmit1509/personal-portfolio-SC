// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

contract Airdrop is Ownable, ReentrancyGuard {
  /**
   * @dev Constructor for Airdrop contract
   * @param _serviceFee service fee of network
   */
  constructor(uint256 _serviceFee) {
    serviceFee = _serviceFee;
  }

  using SafeMath for uint256;

  uint256 serviceFee;

  /**
   * @dev Emitted when `value` tokens are received by smart contract
   * Note that `value` may be zero.
   */
  event Received(address sender, uint256 value);

  /**
   * @dev External function to set service fee of network
   * Reverts if the caller is not owner
   * @param _serviceFee The updated service fee for the contract
   */
  function changeServiceFee(uint256 _serviceFee) external onlyOwner {
    serviceFee = _serviceFee;
  }

  /**
   * @dev External function to transfer tokens to recepient addresses in bulk
   * Reverts if reentrant call is made to the function
   * Reverts if the length of addresses and amounts is not equal
   * Reverts if service fee is not provided
   * Reverts if this smart contract is not approved to transfer tokens
   * @param tokenAddress The address of ERC20 token to be airdropped
   * @param addresses The list of Ethereum addresses
   * @param amounts The amount of tokens to be transferred to respective address
   */
  function transferTokenBulk(
    IERC20 tokenAddress,
    address[] calldata addresses,
    uint256[] calldata amounts
  ) external payable nonReentrant {
    require(
      addresses.length == amounts.length,
      'addresses and amounts must be the same length'
    );
    address from = msg.sender;
    uint256 total = 0;
    for (uint256 i = 0; i < amounts.length; i++) {
      total += amounts[i];
    }
    require(msg.value >= serviceFee, 'Service Fee not provided');
    require(
      tokenAddress.allowance(from, address(this)) >= total,
      'not enough allowance'
    );
    for (uint256 i = 0; i < addresses.length; i++) {
      SafeERC20.safeTransferFrom(tokenAddress, from, addresses[i], amounts[i]);
    }
  }

  /**
   * @dev External function to transfer native currency to recepient addresses in bulk
   * Reverts if reentrant call is made to the function
   * Reverts if the length of addresses and amounts is not equal
   * Reverts if enough currency is not paid (service fee + total transfer amount)
   * @param addresses The list of Ethereum addresses
   * @param amounts The amount of tokens to be transferred to respective address
   */
  function transferCurrencyBulk(
    address[] calldata addresses,
    uint256[] calldata amounts
  ) external payable nonReentrant {
    require(
      addresses.length == amounts.length,
      'addresses and amounts must be the same length'
    );
    uint256 total = 0;
    for (uint256 i = 0; i < amounts.length; i++) {
      total += amounts[i];
    }
    require(msg.value >= total + serviceFee, 'not enough value');
    for (uint256 i = 0; i < addresses.length; i++) {
      payable(addresses[i]).transfer(amounts[i]);
    }
  }

  /**
   * @dev External function to transfer currency stuck in smart contract to EOA address
   * Reverts if reentrant call is made to the function
   * Reverts if the caller is not owner
   * @param amount The amount of tokens to be transferred
   */
  function withdrawCurrency(uint256 amount) external onlyOwner nonReentrant {
    payable(msg.sender).transfer(amount);
  }

  /**
   * @dev External function to transfer tokens stuck in smart contract to EOA address
   * Reverts if reentrant call is made to the function
   * Reverts if the caller is not owner
   * @param tokenAddress The address of ERC20 token to be recovered
   * @param to The Ethereum addresses which will receive the tokens
   * @param amount The amount of tokens to be transferred
   */
  function tokenRecovery(
    IERC20 tokenAddress,
    address to,
    uint256 amount
  ) external onlyOwner nonReentrant {
    SafeERC20.safeTransfer(tokenAddress, to, amount);
  }

  /**
   * The receive function is executed on a call to the contract with empty calldata.
   * This is the function that is executed on plain Ether transfers
   * Event `Received` is emitted when plain ethers are transferred to this contract
   */
  receive() external payable {
    emit Received(msg.sender, msg.value);
  }
}
