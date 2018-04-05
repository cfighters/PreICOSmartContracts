pragma solidity ^0.4.18;
 
import "./SafeMath.sol";
import "./Ownable.sol";
import "./Token.sol";
import "./RefundVault.sol";

contract PreICOCrowdsale is Ownable {
    
  using SafeMath for uint256;
 
  uint256 public publicAllocation = 2892000 * 10 ** uint(18);
  uint256 public softcap = 925440 * 10 ** uint(18);
  uint256 public tokensold = 0;
  
  // start and end timestamps where investments are allowed (both inclusive)
  uint256 public startTime;
  uint256 public endTime;
  uint public PreICOperiod = 30 days;
 
  // address where funds are collected
  address public wallet;
 
  // how many token units a buyer gets per wei
  uint public price = 2000;
 
  // amount of raised money in wei
  uint256 public weiRaised;
  bool public isFinalized = false;
  bool issoftcapreached = false;
  
  RefundVault public vault;
  GemsToken public token;
 
  /**
  * event for token purchase logging
  * @param purchaser who paid for the tokens
  * @param beneficiary who got the tokens
  * @param value weis paid for purchase
  * @param amount amount of tokens purchased
  */
  event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
  event Finalized();
 
 
  function PreICOCrowdsale (address _tokenaddress) public {
    
    wallet = msg.sender;
    owner = msg.sender;
    startTime = now;
    endTime = startTime + PreICOperiod;
    token = GemsToken(_tokenaddress);
    vault = new RefundVault(wallet);
 
  }
  
  //set publicAllocation
  function setpublicallocation (uint256 _value) public onlyOwner {
      publicAllocation = _value * 10 ** uint(token.getdecimals());
  }
 
  //set softcap
  function setsoftcap (uint256 _value) public onlyOwner {
      softcap = _value * 10 ** uint(token.getdecimals());
  }
  
  //set ICOstarttime 
  
  function setStarttime (uint256 _starttime) public onlyOwner {
      startTime = _starttime;
  }

  //set ICOendtime 
  
  function setEndtime (uint256 _endtime) public onlyOwner {
      endTime = _endtime;
  }
  // fallback function can be used to buy tokens
  function () external payable {
    if(msg.sender != owner) buyTokens(msg.sender);
  }
 
  // low level token purchase function
  function buyTokens(address beneficiary) public payable {
    
    uint256 weiAmount = msg.value;
    uint256 tokens = getTokenAmount(weiAmount);
    
    require(beneficiary != address(0));
    require(validPurchase());
    require(tokens <= publicAllocation);
    
    tokensold = tokensold.add(tokens);
    publicAllocation = publicAllocation.sub(tokens);
    
    token.sendCrowdsaleBalance(beneficiary, tokens);
    weiRaised = weiRaised.add(msg.value);
    
    if(tokensold >= softcap && !issoftcapreached) {
        issoftcapreached = true;
        vault.close();
    }
    
    if(issoftcapreached) {
        wallet.transfer(msg.value);
    } else {
        forwardFunds();
    }
  }
 
 
  /**
   * @dev Must be called after crowdsale ends, to do some extra finalization
   * work. Calls the contract's finalization function.
   */
  function finalize() onlyOwner public {
    require(!isFinalized);
    require(hasEnded());
    
    if (!issoftcapreached) {
      vault.enableRefunds();
    }
    
    Finalized();
    isFinalized = true;
  }
  
  // if crowdsale is unsuccessful, investors can claim refunds here
  function claimRefund() public {
    require(isFinalized);
    require(!softcapReached());
 
    vault.refund(msg.sender);
  }
  
 
  
  function softcapReached() public view returns (bool) {
    return tokensold >= softcap;
  }

  // @return true if crowdsale event has ended
  function hasEnded() public view returns (bool) {
    return now > endTime;
  }
 
  // Override this method to have a way to add business logic to your crowdsale when buying
  function getTokenAmount(uint256 weiAmount) internal view returns(uint256) {
    return weiAmount.mul(price);
  }
 
  function forwardFunds() internal {
    vault.deposit.value(msg.value)(msg.sender);
  }
  // @return true if the transaction can buy tokens
  function validPurchase() internal view returns (bool) {
    bool withinPeriod = now >= startTime && now <= endTime;
    bool nonZeroPurchase = msg.value != 0; 
    return withinPeriod && nonZeroPurchase;
  }
  


 
}