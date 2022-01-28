//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";
import "./lib/Ownable.sol";
import "./lib/IERC20.sol";
import "./lib/SafeERC20.sol";
import "./lib/ReentrancyGuard.sol";
//import "./lib/console.sol";

pragma experimental ABIEncoderV2;

contract MarsDAOLottery is VRFConsumerBase, Ownable, ReentrancyGuard {

    using SafeERC20 for IERC20;

    address public constant burnAddress =
        0x000000000000000000000000000000000000dEaD;
    bytes32 public keyHash=0xc251acd21ec4fb7f31bb8868288bfdbaeb4fbfec2df3735ddbd4f7dc8d60103c;//(Binance Smart Chain Mainnet)
    uint256 public randomOracleFee=200000000000000000;//0.2 LINK
    uint256 public pendingPriceTicketInMars=50*1e18;
    IERC20 immutable public marsToken;
    address immutable public feeAddress;
    uint256 constant public feeBP=200;
    uint256 constant public burnBP=800;
    uint256 public constant BP=10000;
    mapping(bytes32=>uint256) private latestRequest;

    event LotteryDrawOpened(uint256 lotteryId);
    event LotteryDrawClosed(uint256 lotteryId, uint256 finalNumber);
    event LotteryCanceled(uint256 lotteryId);


    enum Status {
        NotExist,
        Open,
        Close,
        Claimable,
        Canceled
    }

    struct Lottery {
        uint256 priceTicketInMars;
        uint256 lastTicketId;
        uint256 finalNumber;
        uint256 rewardBalance;
    }
    

    mapping(address => mapping(uint256=>uint256[])) private tickets;
    Lottery[] private lotteries;


    modifier notContract() {
        require(!_isContract(msg.sender), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }

    constructor(address _marsToken,
                address _feeAddress,
                address _vrfCoordinator, 
                address _linkToken) VRFConsumerBase(_vrfCoordinator, _linkToken)  public {
        marsToken=IERC20(_marsToken);
        feeAddress=_feeAddress;
        lotteries.push(Lottery(pendingPriceTicketInMars,0,0,0));
        require(feeBP.add(burnBP)==1000,"feeBP+burnBP must eq 1000");
        emit LotteryDrawOpened(0);
    }

    function buyTickets(uint256 numberOfTickets)
        external
        notContract
        nonReentrant
    {
        require(numberOfTickets>0, 
        "number of tickets is null!");
        
        uint256 latestLotteryId=getCurrentLotteryId();
        
        require(getLotteryStatus(latestLotteryId)==Status.Open,
        "Buying in this contract is not more available .");

        Lottery storage currentLottery=lotteries[latestLotteryId];
        uint256[] storage userTickets=tickets[msg.sender][latestLotteryId];

        uint256 lastTicketId=currentLottery.lastTicketId;
        if(lastTicketId.add(numberOfTickets)>100){
            numberOfTickets=uint256(100).sub(lastTicketId);
        }
        uint256 paymentAmount=currentLottery.priceTicketInMars.mul(numberOfTickets);
        marsToken.safeTransferFrom(
                                    address(msg.sender), 
                                    address(this), 
                                    paymentAmount
                                );

        currentLottery.rewardBalance=currentLottery.rewardBalance.add(paymentAmount);

        for (uint256 i = 0; i < numberOfTickets; i++) {
            lastTicketId++;
            userTickets.push(lastTicketId);
            if(lastTicketId==100){
                //close
                currentLottery.lastTicketId = 100;
                bytes32 reqId=getRandomNumber(
                   uint256(keccak256(abi.encodePacked(latestLotteryId, block.timestamp)))
                );
                latestRequest[reqId]=latestLotteryId;
                //open
                lotteries.push(Lottery(pendingPriceTicketInMars,0,0,0));
                emit LotteryDrawOpened(latestLotteryId.add(1));
                return;
            }
        }
        currentLottery.lastTicketId = lastTicketId;
    }

    function claimTickets(uint256 _lotteryId) external {
        
        uint256 reward=calculateRewards(_lotteryId,msg.sender);
        if(reward>0){
            Lottery storage currentLottery=lotteries[_lotteryId];
            delete tickets[msg.sender][_lotteryId];
            uint256 maxRewardBalance=currentLottery.priceTicketInMars.mul(100);
            uint256 feeAmount=0;
            uint256 burnAmount=0;
            if(currentLottery.rewardBalance==maxRewardBalance 
            && getLotteryStatus(_lotteryId)!=Status.Canceled){
                feeAmount=maxRewardBalance.mul(feeBP).div(BP);
                burnAmount=maxRewardBalance.mul(burnBP).div(BP);
                marsToken.safeTransfer(feeAddress,feeAmount);
                marsToken.safeTransfer(burnAddress,burnAmount);
                currentLottery.rewardBalance=currentLottery.rewardBalance.sub(feeAmount.add(burnAmount));
            }

            currentLottery.rewardBalance=currentLottery.rewardBalance.sub(reward);
            marsToken.safeTransfer(msg.sender, reward);
        }
    }

    function calculateRewards(uint256 _lotteryId,address _user) public view returns (uint256){
        
        uint256[] memory userTickets=tickets[_user][_lotteryId];
        Lottery memory currentLottery=lotteries[_lotteryId];
        Status lottaryStatus=getLotteryStatus(_lotteryId);

        if(lottaryStatus==Status.Canceled){
            return userTickets.length.mul(currentLottery.priceTicketInMars);
        }

        if(lottaryStatus!=Status.Claimable 
        || userTickets.length==0){
            return 0;
        }
        
        
        uint256 reward=0;

        for(uint256 i=0;i<userTickets.length;i++){
            if(userTickets[i]==currentLottery.finalNumber){
                reward=reward.add(currentLottery.priceTicketInMars.mul(5));
            }else{
                if(userTickets[i]<currentLottery.finalNumber){
                    userTickets[i]=currentLottery.finalNumber.sub(userTickets[i]).add(100);
                }
                if(userTickets[i]==currentLottery.finalNumber.add(1)){
                    reward=reward.add(currentLottery.priceTicketInMars.mul(3));
                }else if(userTickets[i]==currentLottery.finalNumber.add(2)){
                    reward=reward.add(currentLottery.priceTicketInMars.mul(2));
                }else if(userTickets[i]<=currentLottery.finalNumber.add(12)){
                    reward=reward.add(currentLottery.priceTicketInMars.mul(14).div(10));
                }else if(userTickets[i]<=currentLottery.finalNumber.add(22)){
                    reward=reward.add(currentLottery.priceTicketInMars.mul(13).div(10));
                }else if(userTickets[i]<=currentLottery.finalNumber.add(32)){
                    reward=reward.add(currentLottery.priceTicketInMars.mul(12).div(10));
                }else if(userTickets[i]<=currentLottery.finalNumber.add(42)){
                    reward=reward.add(currentLottery.priceTicketInMars.mul(11).div(10));
                }else if(userTickets[i]<=currentLottery.finalNumber.add(52)){
                    reward=reward.add(currentLottery.priceTicketInMars);
                }else{
                    reward=reward.add(currentLottery.priceTicketInMars.mul(20).div(47));
                }
            }
        }
        return reward;
    }

    function getUserTickets(uint256 _lotteryId,address _user) public view returns (uint256[] memory){
        return tickets[_user][_lotteryId];
    }

    function getCurrentLotteryId() public view returns (uint256) {
        return lotteries.length.sub(1);
    }

    function getLotteryStatus(uint256 _lotteryId) public view returns (Status) {
        
        if(_lotteryId<lotteries.length){
            if(lotteries[_lotteryId].finalNumber>0){
                if(lotteries[_lotteryId].finalNumber==101){
                    return Status.Canceled;
                }
                return Status.Claimable;
            }
            if(_lotteryId==(lotteries.length-1)){
                return Status.Open;
            }
            return Status.Close;
        }
        
        return Status.NotExist;
    }

    function getLottery(uint256 _lotteryId) public view returns (Lottery memory) {
        return lotteries[_lotteryId];
    }

    function getRandomNumber(uint256 seed) private returns(bytes32){
        require(keyHash != bytes32(0), "Must have valid key hash");
        require(LINK.balanceOf(address(this)) >= randomOracleFee, "Not enough LINK tokens");
        return requestRandomness(keyHash, randomOracleFee, seed);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        uint256 lotteryId=latestRequest[requestId];
        Lottery storage currentLottery=lotteries[lotteryId];
        require(currentLottery.finalNumber == 0 && currentLottery.lastTicketId==100, "Wrong requestId");
        currentLottery.finalNumber=randomness.mod(100).add(1);
        emit LotteryDrawClosed(lotteryId, currentLottery.finalNumber);
    }

    function setPriceTicketInMars(uint256 _priceTicketInMars) external onlyOwner {
        pendingPriceTicketInMars = _priceTicketInMars;
    }

    function cancelLottaryAndCloseContract() external onlyOwner {
        uint256 latestLotteryId=getCurrentLotteryId();
        lotteries[latestLotteryId].finalNumber=101;
        emit LotteryCanceled(latestLotteryId);
    }

    function setRandomOracleFee(uint256 _randomOracleFee) external onlyOwner {
        randomOracleFee = _randomOracleFee;
    }

    function setKeyHash(bytes32 _keyHash) external onlyOwner {
        keyHash = _keyHash;
    }

    function withdrawLINK(address to, uint256 value) public onlyOwner {
        require(LINK.transfer(to, value), "Not enough LINK");
    }
    
    function _isContract(address _addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }

}