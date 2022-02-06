const { web3 } = require('@openzeppelin/test-helpers/src/setup');
const MarsDAOLottery = artifacts.require('MarsDAOLottery');
const MarsTpokenERC20 = artifacts.require('MockERC20');

module.exports = async (deployer, network) => {
  
  if (network == "bscmain") { 
    const marsAddress="not deployed yet";
    const VRFCoordinator="0x747973a5A2a4Ae1D3a8fDF5479f1514F65Db9C31";
    const LINKToken="0x404460C6A5EdE2D891e8297795264fDe62ADBB75";
    const feeAdr="0x9724EC9c28AB13BE9E24C1834cb6f0c8949Aff6f";
    try{
      await deployer.deploy(MarsDAOLottery,marsAddress,feeAdr,VRFCoordinator,LINKToken);
    }catch(err){
      console.log("ERROR:",err);
    }
  }else if(network == "bsctest"){
    // BSC Faucet LINK  https://faucets.chain.link/chapel
    const VRFCoordinator="0xa555fC018435bef5A13C6c6870a9d4C11DEC329C";
    const LINKToken="0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06";
    const feeAdr="0x53D8481C4ee35bC789E1acaB7129e8dF1205C519";
    const keyHash="0xcaf3c3727e033261d383b315559476f48034c13b18f8cafed4d871abe5049186";
    try{
      const fee=web3.utils.toWei("0.1", "ether");
      await deployer.deploy(MarsTpokenERC20,'newMars', 'newMars', web3.utils.toWei("10000000", "ether"));
      await deployer.deploy(MarsDAOLottery,MarsTpokenERC20.address,feeAdr,VRFCoordinator,LINKToken);
      const MarsDAOLotteryInstance = await MarsDAOLottery.deployed();
      await MarsDAOLotteryInstance.setRandomOracleFee(fee);
      await MarsDAOLotteryInstance.setKeyHash(keyHash);
    }catch(err){
      console.log("ERROR:",err);
    }
  }
};
