
const MarsDAOLottery = artifacts.require('MarsDAOLottery');

module.exports = async (deployer, network) => {
  
  if (network == "bscmain") { 
    try{
      const marsAddress="not deployed yet";
      const VRFCoordinator="0x747973a5A2a4Ae1D3a8fDF5479f1514F65Db9C31";
      const LINKToken="0x404460C6A5EdE2D891e8297795264fDe62ADBB75";
      const feeAdr="0x9724EC9c28AB13BE9E24C1834cb6f0c8949Aff6f";
      await deployer.deploy(MarsDAOLottery,marsAddress,feeAdr,VRFCoordinator,LINKToken);
    }catch(err){
      console.log("ERROR:",err);
    }
  }
};
