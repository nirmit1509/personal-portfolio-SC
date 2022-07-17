// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';

abstract contract ERC20TokenInterface {
  function totalSupply() external virtual returns (uint256);

  function balanceOf(address tokenOwner)
    external
    virtual
    returns (uint256 balance);

  function transfer(address to, uint256 tokens)
    external
    virtual
    returns (bool success);

  function transferFrom(
    address from,
    address to,
    uint256 tokens
  ) external virtual returns (bool success);
}

/**
 * DreamTeam tokens vesting contract.
 *
 * According to the DreamTeam token distribution structure, there are two parties that should
 * be provided with corresponding token amounts during the 2 years after TGE:
 *      Teams and Tournament Organizers: 15%
 *      Team and Early Investors: 10%
 *
 * The DreamTeam "Vesting" smart contract should be in place to ensure meeting the token sale commitments.
 *
 * Two instances of the contract will be deployed for holding tokens.
 * First instance for "Teams and Tournament Organizers" tokens and second for "Team and Early Investors".
 */
contract DreamTokensVesting {
  using SafeMath for uint256;

  /**
   * Address of DreamToken.
   */
  ERC20TokenInterface public dreamToken;

  /**
   * Address for receiving tokens.
   */
  address public withdrawAddress;

  /**
   * Tokens vesting stage structure with vesting date and tokens allowed to unlock.
   */
  struct VestingStage {
    uint256 date;
    uint256 tokensUnlockedPercentage;
  }

  /**
   * Array for storing all vesting stages with structure defined above.
   */
  VestingStage[5] public stages;

  /**
   * Starting timestamp of the first stage of vesting (Tuesday, 19 June 2018, 09:00:00 GMT).
   * Will be used as a starting point for all dates calculations.
   */
  uint256 public vestingStartTimestamp = 1529398800;

  /**
   * Total amount of tokens sent.
   */
  uint256 public initialTokensBalance;

  /**
   * Amount of tokens already sent.
   */
  uint256 public tokensSent;

  /**
   * Event raised on each successful withdraw.
   */
  event Withdraw(uint256 amount, uint256 timestamp);

  /**
   * Could be called only from withdraw address.
   */
  modifier onlyWithdrawAddress() {
    require(msg.sender == withdrawAddress);
    _;
  }

  /**
   * We are filling vesting stages array right when the contract is deployed.
   *
   * @param token Address of DreamToken that will be locked on contract.
   * @param withdraw Address of tokens receiver when it is unlocked.
   */
  constructor(ERC20TokenInterface token, address withdraw) {
    dreamToken = token;
    withdrawAddress = withdraw;
    initVestingStages();
  }

  /**
   * Fallback
   */
  receive() external payable {
    withdrawTokens();
  }

  function getAvailableTokensToWithdraw()
    public
    returns (uint256 tokensToSend)
  {
    uint256 tokensUnlockedPercentage = getTokensUnlockedPercentage();
    // In the case of stuck tokens we allow the withdrawal of them all after vesting period ends.
    if (tokensUnlockedPercentage >= 100) {
      tokensToSend = dreamToken.balanceOf(address(this));
    } else {
      tokensToSend = getTokensAmountAllowedToWithdraw(tokensUnlockedPercentage);
    }
  }

  function getStageAttributes(uint8 index)
    public
    view
    returns (uint256 date, uint256 tokensUnlockedPercentage)
  {
    return (stages[index].date, stages[index].tokensUnlockedPercentage);
  }

  /**
   * Setup array with vesting stages dates and percents.
   */
  function initVestingStages() internal {
    uint256 halfOfYear = 183 days;
    uint256 year = halfOfYear * 2;
    stages[0].date = vestingStartTimestamp;
    stages[1].date = vestingStartTimestamp + halfOfYear;
    stages[2].date = vestingStartTimestamp + year;
    stages[3].date = vestingStartTimestamp + year + halfOfYear;
    stages[4].date = vestingStartTimestamp + year * 2;

    stages[0].tokensUnlockedPercentage = 25;
    stages[1].tokensUnlockedPercentage = 50;
    stages[2].tokensUnlockedPercentage = 75;
    stages[3].tokensUnlockedPercentage = 88;
    stages[4].tokensUnlockedPercentage = 100;
  }

  /**
   * Main method for withdraw tokens from vesting.
   */
  function withdrawTokens() private onlyWithdrawAddress {
    // Setting initial tokens balance on a first withdraw.
    if (initialTokensBalance == 0) {
      setInitialTokensBalance();
    }
    uint256 tokensToSend = getAvailableTokensToWithdraw();
    sendTokens(tokensToSend);
  }

  /**
   * Set initial tokens balance when making the first withdrawal.
   */
  function setInitialTokensBalance() private {
    initialTokensBalance = dreamToken.balanceOf(address(this));
  }

  /**
   * Send tokens to withdrawAddress.
   *
   * @param tokensToSend Amount of tokens will be sent.
   */
  function sendTokens(uint256 tokensToSend) private {
    if (tokensToSend > 0) {
      // Updating tokens sent counter
      tokensSent = tokensSent.add(tokensToSend);
      // Sending allowed tokens amount
      dreamToken.transfer(withdrawAddress, tokensToSend);
      // Raising event
      emit Withdraw(tokensToSend, block.timestamp);
    }
  }

  /**
   * Calculate tokens available for withdrawal.
   *
   * @param tokensUnlockedPercentage Percent of tokens that are allowed to be sent.
   *
   * @return Amount of tokens that can be sent according to provided percentage.
   */
  function getTokensAmountAllowedToWithdraw(uint256 tokensUnlockedPercentage)
    private
    view
    returns (uint256)
  {
    uint256 totalTokensAllowedToWithdraw = initialTokensBalance
      .mul(tokensUnlockedPercentage)
      .div(100);
    uint256 unsentTokensAmount = totalTokensAllowedToWithdraw.sub(tokensSent);
    return unsentTokensAmount;
  }

  /**
   * Get tokens unlocked percentage on current stage.
   *
   * @return Percent of tokens allowed to be sent.
   */
  function getTokensUnlockedPercentage() private view returns (uint256) {
    uint256 allowedPercent;

    for (uint8 i = 0; i < stages.length; i++) {
      if (block.timestamp >= stages[i].date) {
        allowedPercent = stages[i].tokensUnlockedPercentage;
      }
    }

    return allowedPercent;
  }
}

contract TeamAndEarlyInvestorsVesting is DreamTokensVesting {
  constructor(ERC20TokenInterface token, address withdraw)
    DreamTokensVesting(token, withdraw)
  {}
}
