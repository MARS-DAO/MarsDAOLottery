const { expectRevert, time,BN,ether} = require('@openzeppelin/test-helpers');
const { ethers, network } = require('hardhat');
const { array } = require('yargs');
const ForceSend = artifacts.require('ForceSend');
const MarsDAOLottery = artifacts.require('MarsDAOLottery');
const MockERC20 = artifacts.require('MockERC20');
const IERC20= artifacts.require('IERC20');
//Binance Smart Chain Mainnet
const VRFCoordinator="0x747973a5A2a4Ae1D3a8fDF5479f1514F65Db9C31";
const LINKToken="0x404460C6A5EdE2D891e8297795264fDe62ADBB75";
const LINK_DONOR_ADDRESS="0x6f61507F902e1c22BCd7aa2C0452cd2212009B61";

contract('MarsDAOLottery', ([alice, bob, carol, scot,developer]) => {

    before(async () => {
        this.link=await IERC20.at(LINKToken);
        this.newMars = await MockERC20.new('newMars', 'newMars', web3.utils.toWei("10000000", "ether"), { from: alice });
        this.MarsDAOLottery = await MarsDAOLottery.new(this.newMars.address,developer,VRFCoordinator,LINKToken, { from: alice });
        await this.newMars.transfer(bob,web3.utils.toWei("10000", "ether"),{ from: alice });
        await this.newMars.transfer(carol,web3.utils.toWei("10000", "ether"),{ from: alice });
        await this.newMars.transfer(scot,web3.utils.toWei("10000", "ether"),{ from: alice });
        await this.newMars.transfer(developer,web3.utils.toWei("10000", "ether"),{ from: alice });
        await this.newMars.approve(this.MarsDAOLottery.address, web3.utils.toWei("10000", "ether"), { from: alice });
        await this.newMars.approve(this.MarsDAOLottery.address, web3.utils.toWei("10000", "ether"), { from: bob });
        await this.newMars.approve(this.MarsDAOLottery.address, web3.utils.toWei("10000", "ether"), { from: carol });
        await this.newMars.approve(this.MarsDAOLottery.address, web3.utils.toWei("10000", "ether"), { from: scot });
        await this.newMars.approve(this.MarsDAOLottery.address, web3.utils.toWei("10000", "ether"), { from: developer });
        
        await network.provider.request({
            method: 'hardhat_impersonateAccount',
            params: [LINK_DONOR_ADDRESS],
        });

        await this.link.transfer(this.MarsDAOLottery.address,web3.utils.toWei("10000", "ether"),{ from: LINK_DONOR_ADDRESS });
        const forceSend = await ForceSend.new();
        await forceSend.go(VRFCoordinator, { value: web3.utils.toWei("1", "ether") });

    });

    it('buyTickets', async () => {
        await this.MarsDAOLottery.buyTickets(20,{ from: alice });
        await this.MarsDAOLottery.buyTickets(20,{ from: bob });
        await this.MarsDAOLottery.buyTickets(20,{ from: carol });
        await this.MarsDAOLottery.buyTickets(20,{ from: scot });
        expect((await this.MarsDAOLottery.getCurrentLotteryId()).toString(10)).to.eq('0');
        expect((await this.MarsDAOLottery.getLotteryStatus(0)).toString(10)).to.eq('1');//Open
        await this.MarsDAOLottery.buyTickets(20,{ from: developer });
        expect((await this.MarsDAOLottery.getCurrentLotteryId()).toString(10)).to.eq('1');
        expect((await this.MarsDAOLottery.getLotteryStatus(0)).toString(10)).to.eq('2');//Close
        expect((await this.MarsDAOLottery.getLotteryStatus(1)).toString(10)).to.eq('1');//Open
        
        await network.provider.request({
            method: 'hardhat_impersonateAccount',
            params: [VRFCoordinator],
        });
        const random=Math.floor(Math.random() * 1000000000 + 1);
        await this.MarsDAOLottery.rawFulfillRandomness(
            "0x5ef4728da6fde089829f5ec2bbe9820910cc1593f0294a82189b3ede8aeb4b4e", 
            random,{from: VRFCoordinator});
        expect((await this.MarsDAOLottery.getLotteryStatus(0)).toString(10)).to.eq('3');//Claimable
        expect((await this.MarsDAOLottery.getLottery(0)).rewardBalance)
        .to.eq((await this.newMars.balanceOf(this.MarsDAOLottery.address)).toString(10));
        //console.log(await this.MarsDAOLottery.getUserTicketsByLottariesList(100,bob));
    });

    it('claimTickets', async () => {
        await this.MarsDAOLottery.claimTickets(0,{ from: alice });
        await this.MarsDAOLottery.claimTickets(0,{ from: bob });
        await this.MarsDAOLottery.claimTickets(0,{ from: carol });
        await this.MarsDAOLottery.claimTickets(0,{ from: scot });
        await this.MarsDAOLottery.claimTickets(0,{ from: developer });
        expect((await this.MarsDAOLottery.getLottery(0)).rewardBalance)
        .to.eq((await this.newMars.balanceOf(this.MarsDAOLottery.address)).toString(10));
    }); 
    
    it('cancelLottaryAndStopContract', async () => {
        await this.MarsDAOLottery.buyTickets(20,{ from: alice });
        await this.MarsDAOLottery.buyTickets(20,{ from: bob });
        await this.MarsDAOLottery.cancelLottaryAndStopContract({ from: alice });
        await expectRevert(
            this.MarsDAOLottery.buyTickets(20,{ from: scot }),
            'Buying in this contract is not more available.'
        );
        await this.MarsDAOLottery.claimTickets(1,{ from: alice });
        await this.MarsDAOLottery.claimTickets(1,{ from: bob });
        expect((await this.MarsDAOLottery.getLottery(0)).rewardBalance)
        .to.eq((await this.newMars.balanceOf(this.MarsDAOLottery.address)).toString(10));
        expect((await this.MarsDAOLottery.getLottery(1)).rewardBalance)
        .to.eq('0');

    });

});