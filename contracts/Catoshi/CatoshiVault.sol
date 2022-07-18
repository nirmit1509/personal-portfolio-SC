// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract Vault is Ownable {
  using Address for address;

  function transferamount(
    uint256 amount,
    address _recipient,
    address token
  ) external onlyOwner returns (bool) {
    require(msg.sender.isContract(), 'Not an address');
    IERC20(token).transfer(_recipient, amount);
    return true;
  }

  function reserve(address token) public view returns (uint256) {
    return IERC20(token).balanceOf(address(this));
  }
}
