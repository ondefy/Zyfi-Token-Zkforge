// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ZFIToken} from "../src/ZFI/ZFIToken.sol";

contract ZFINewImplementation_test is Test {
    address TEAM_ADDRESS = 0x336044E117fA0e786eE1A58b4a54a9969AA288De;
    address DEPLOYER_ADDRESS = 0xA47dF9473fF4084BA4d11271cA8a470361D77a09;
    address USER1 = makeAddr("USER1");
    ZFIToken zfiToken = ZFIToken(0x5d0d7BCa050e2E98Fd4A5e8d3bA823B49f39868d);
    address newImplementation = 0x9f4D380c867EBaed8140C332c78BF32Eb52A01Fb;

    function setUp() public {
        deal(DEPLOYER_ADDRESS, 2 ether);
        // upgrade
        vm.startPrank(TEAM_ADDRESS);
        zfiToken.upgradeToAndCall(newImplementation, "");
        vm.stopPrank();
    }

    // function deploy_ZFI() public returns(address ZFI_proxy_address){
    //     address ZFITokenImplementation = address(new ZFIToken());
    //     ZFI_proxy_address = address(new ERC1967Proxy(ZFITokenImplementation, abi.encodeCall(ZFIToken.initialize2, (TEAM_ADDRESS))));
    // }

    function test_RemoveAdminRole() public {
        vm.deal(TEAM_ADDRESS, 2 ether);
        vm.startPrank(TEAM_ADDRESS);
        zfiToken.revokeRole(zfiToken.DEFAULT_ADMIN_ROLE(), DEPLOYER_ADDRESS);
        vm.stopPrank();
        assertTrue(zfiToken.hasRole(zfiToken.DEFAULT_ADMIN_ROLE(), TEAM_ADDRESS));
        assertFalse(zfiToken.hasRole(zfiToken.DEFAULT_ADMIN_ROLE(), DEPLOYER_ADDRESS));
    }

    function test_Mint() public {
        vm.startPrank(DEPLOYER_ADDRESS);
        zfiToken.mint(USER1, 10 ether);
        vm.stopPrank();
        assertTrue(zfiToken.balanceOf(USER1) == 10 ether);
    }

    function test_Pause() public {
        vm.startPrank(TEAM_ADDRESS);
        zfiToken.revokeRole(zfiToken.DEFAULT_ADMIN_ROLE(), DEPLOYER_ADDRESS);
        zfiToken.revokeRole(zfiToken.PAUSER_ROLE(), DEPLOYER_ADDRESS);
        vm.startPrank(DEPLOYER_ADDRESS);
        zfiToken.mint(USER1, 10 ether);
        vm.stopPrank();
        vm.startPrank(TEAM_ADDRESS);
        zfiToken.grantRole(zfiToken.PAUSER_ROLE(), TEAM_ADDRESS);
        zfiToken.pause();
        vm.stopPrank();
        vm.startPrank(USER1);
        vm.expectRevert();
        zfiToken.transfer(DEPLOYER_ADDRESS, 10 ether);
    }

    function test_Upgrade() public {
        vm.startPrank(TEAM_ADDRESS);
        zfiToken.revokeRole(zfiToken.DEFAULT_ADMIN_ROLE(), DEPLOYER_ADDRESS);        address newImplem =  address(new ZFIToken());
        bytes memory data = "";
        zfiToken.upgradeToAndCall(newImplem, data);
    }

    function test_nameAndTicker() public {
        assertEq(zfiToken.name(), "Zyfi Token");
        assertEq(zfiToken.symbol(), "ZFI");
        assertEq(zfiToken.totalSupply(), 500000000000000000000000000);
    }

    //TODO: test balance changes
    function test_balances() public {
assertEq(zfiToken.balanceOf(0x2512A3569f617be0E42daE20651d0F567A9F2216), 165000000 ether );
assertEq(zfiToken.balanceOf(0x274F5c75bf69CCA1c4689100bfa57700C98E4927), 58623065.523021312727820337 ether );
assertEq(zfiToken.balanceOf(0x5ad9AF59ae6a0d15fC6dE41Fc33275f030650761), 40000000 ether );
// assertEq(zfiToken.balanceOf(0xFE4026815f58ceF3780Fb2e2A52934aBa902b34c), 22858180545735786126407107 );
assertEq(zfiToken.balanceOf(0xdb6047C3687CD1100964af35bF40e21F0822f7D7), 7692017.623843821469651738 ether );
// assertEq(zfiToken.balanceOf(0xeC706FcDCA09273945AE7C3C4d29e4a5f4482a23), 5343174690853590437060598 );
assertEq(zfiToken.balanceOf(0x6E146F035DDC31d8e8466CFC1226289cc0515338), 2354915.4848265 ether );
assertEq(zfiToken.balanceOf(0xb3DDFd20a48972733f0Bb7D332A09154C5Ed3E1a), 1749020.081023451952174707 ether );
assertEq(zfiToken.balanceOf(0x6518061550014120371f8CD969739C41fc9DE30B), 1106421.773098348881914548 ether );
assertEq(zfiToken.balanceOf(0x2EF0480594B65e24be29FB2EaA78E288c4D6baCC), 658489.420701478651497598 ether );
assertEq(zfiToken.balanceOf(0xeEca25Bf32ca14616F2e4bB79AD017E8f70247BE), 461856.958799797697697696 ether );
assertEq(zfiToken.balanceOf(0xe5A4F60eC4be0217d30998381D24804991720616), 453892.283289832207604479 ether );
assertEq(zfiToken.balanceOf(0x391433C0dcCAb44dC1FA39B5431a40Ba8BedA286), 396910.682143750040725 ether );
assertEq(zfiToken.balanceOf(0x86e243c78bB27B3a9B2b5939feEBc85a3be8e67d), 222222.22224 ether );
assertEq(zfiToken.balanceOf(0xEA28FD274cB6454993D5C33342a6FE7eA63f8e0C), 157772.142169848169856875 ether );
assertEq(zfiToken.balanceOf(0xC1CeeBC9fA951964Bb7766F5f56989abe02941aC), 144457.189829481890606077 ether );
assertEq(zfiToken.balanceOf(0x9a26991E5ea87353e3e9cF282Aaf237c8BB61d27), 129166.6668 ether );
assertEq(zfiToken.balanceOf(0x135735CfFa8B760775c2d07bC3df6f41eAd3bfe2), 112604.791792237996262736 ether );
assertEq(zfiToken.balanceOf(0xA6f7F9D3405DF427fc2cf5aAc6BD10119cBc692F), 111111.11112 ether );
assertEq(zfiToken.balanceOf(0xD260fE89A1D61d199Fd2825c38CA373935F725a2), 111111 ether );
assertEq(zfiToken.balanceOf(0xAef18C8794cA00e914E318743732AE4E32c1b614), 104166.9164 ether );
assertEq(zfiToken.balanceOf(0xd4D2669A1A40c612B85698Fa3f1E6BC9332C46d1), 102480.834166561934784765 ether );
assertEq(zfiToken.balanceOf(0x876cda017525A4bBe40852B53f5AF4AA533765DB), 87840.44702890838386268 ether );
assertEq(zfiToken.balanceOf(0x935F38d15Ff402777bDe0a0FaE992b040FCf3F46), 83300.003400000000000001 ether );
assertEq(zfiToken.balanceOf(0x627A34B3b8C059D2905C678cd8E61D253D6b5B59), 70034.968685698230658926 ether );
assertEq(zfiToken.balanceOf(0x2748f4cE2054E0E5B38aCCFeE401cd4a3F8a0fc6), 69611.381698623435643558 ether );
assertEq(zfiToken.balanceOf(0xfb4334A5704e29DF37efc9F16255759670018D9A), 65828.109802074524076455 ether );
assertEq(zfiToken.balanceOf(0x9F75F7629306e72C512DbE55D0dfd150034e443e), 60000 ether );
assertEq(zfiToken.balanceOf(0xb6F67F980F46b60Fa1D606165B5dd2601DF4Bb30), 53704.439706716676021995 ether );
assertEq(zfiToken.balanceOf(0x0056964837710BeD88bD40988C83507cEC54EC02), 52320.494255481048299454 ether );
assertEq(zfiToken.balanceOf(0x6b32749F69C663980AD86c2D0488206E13489144), 50000.0001 ether );
assertEq(zfiToken.balanceOf(0x99f191a5FfE2C23076c5a911aAB15AA258337453), 46410.177569533777988697 ether );
assertEq(zfiToken.balanceOf(0x8C4203C94aBc055b0435dd9F666Ac19Ba71B4791), 38427.051081065694232576 ether );
assertEq(zfiToken.balanceOf(0x5C7D143c6d5fab7C5FAB40F44dC39469466eb205), 36681.711426704763628907 ether );
assertEq(zfiToken.balanceOf(0x0aB866Ba4BF87446879C37eFBd5e5096fb9740AB), 29434.869235962619283564 ether );
assertEq(zfiToken.balanceOf(0x55eE93F2e06c7322Efd96765D21c68FEfBaA7f43), 26717.855336356475276829 ether );
assertEq(zfiToken.balanceOf(0xF1a8ACfe658f2986D097e9ee388d71bE34FbB6FF), 24282.974194449880531684 ether );
assertEq(zfiToken.balanceOf(0x20905A34EeA344428ed8361407E445E10446096d), 21250 ether );
assertEq(zfiToken.balanceOf(0xA45bc88fBb71DD5a095d8cCD4A9Aa050Cd217A92), 20737 ether );
assertEq(zfiToken.balanceOf(0x0E8c00aeddA237C54F860e614062EFce5C40786C), 20000.01 ether );
assertEq(zfiToken.balanceOf(0xB182D6f0007917caD7E9344268AEdD76e8268E4e), 20000 ether );
assertEq(zfiToken.balanceOf(0x7FCE5E3d6f46C10790372e11a954455C27269835), 19737 ether );
assertEq(zfiToken.balanceOf(0x94c372CC77eDC65c4177dbAdd35235ea57917F09), 18448.093540424506143043 ether );
assertEq(zfiToken.balanceOf(0x2F53d275edFc1e73162afFcDD3B7cc8C0B4D596D), 18422.00610550185464362 ether );
assertEq(zfiToken.balanceOf(0x8814D33B1A88F9B4C60de09F22E9744039FC59d9), 16634.832123018841960091 ether );
assertEq(zfiToken.balanceOf(0x3E1545785b538be9D8C70775E2aC4506e2775EA9), 16209.153895714155239773 ether );
assertEq(zfiToken.balanceOf(0x8175732F812aF3aff7cF5f73dFcF947c9EeF279C), 16000 ether );
assertEq(zfiToken.balanceOf(0xE9b9d3aCa653Fb43B946a02D9334C548571cA368), 15777.06376 ether );
assertEq(zfiToken.balanceOf(0x5B9D7089Dd11b5f8B35968048755E1bE04d2D861), 15598.028073669558063026 ether );
    }


// Define the addresses and their initial balances
address addr1 = 0x2EF0480594B65e24be29FB2EaA78E288c4D6baCC; // Balance: 658,489.420701478651497598 ether
address addr2 = 0xFE4026815f58ceF3780Fb2e2A52934aBa902b34c; // Balance: 22,860,547.342966070973109699 ether
address addr3 = 0xdb6047C3687CD1100964af35bF40e21F0822f7D7; // Balance: 7,692,017.623843821469651738 ether
address addr4 = 0x5ad9AF59ae6a0d15fC6dE41Fc33275f030650761; // Balance: 40,000,000 ether
address addr5 = 0x6E146F035DDC31d8e8466CFC1226289cc0515338; // Balance: 2,354,915.4848265 ether
address addr6 = 0xeC706FcDCA09273945AE7C3C4d29e4a5f4482a23; // Balance: 5,344,163.765914362687219783 ether
address addr7 = 0xb3DDFd20a48972733f0Bb7D332A09154C5Ed3E1a; // Balance: 1,749,020.081023451952174707 ether
address addr8 = 0x6518061550014120371f8CD969739C41fc9DE30B; // Balance: 1,106,421.773098348881914548 ether

function testTokenTransfers() public {
    // Transfer 100,000 ether from addr1 to addr2
    uint256 amount1 = 100_000 ether;
    uint256 senderOldBalance1 = zfiToken.balanceOf(addr1);
    uint256 receiverOldBalance1 = zfiToken.balanceOf(addr2);

    vm.startPrank(addr1);
    zfiToken.transfer(addr2, amount1);
    vm.stopPrank();

    uint256 senderNewBalance1 = zfiToken.balanceOf(addr1);
    uint256 receiverNewBalance1 = zfiToken.balanceOf(addr2);

    assertEq(senderNewBalance1, senderOldBalance1 - amount1);
    assertEq(receiverNewBalance1, receiverOldBalance1 + amount1);

    // Transfer 500,000 ether from addr3 to addr4
    uint256 amount2 = 500_000 ether;
    uint256 senderOldBalance2 = zfiToken.balanceOf(addr3);
    uint256 receiverOldBalance2 = zfiToken.balanceOf(addr4);

    vm.startPrank(addr3);
    zfiToken.transfer(addr4, amount2);
    vm.stopPrank();

    uint256 senderNewBalance2 = zfiToken.balanceOf(addr3);
    uint256 receiverNewBalance2 = zfiToken.balanceOf(addr4);

    assertEq(senderNewBalance2, senderOldBalance2 - amount2);
    assertEq(receiverNewBalance2, receiverOldBalance2 + amount2);

    // Transfer 1,000 ether from addr5 to addr6
    uint256 amount3 = 1_000 ether;
    uint256 senderOldBalance3 = zfiToken.balanceOf(addr5);
    uint256 receiverOldBalance3 = zfiToken.balanceOf(addr6);

    vm.startPrank(addr5);
    zfiToken.transfer(addr6, amount3);
    vm.stopPrank();

    uint256 senderNewBalance3 = zfiToken.balanceOf(addr5);
    uint256 receiverNewBalance3 = zfiToken.balanceOf(addr6);

    assertEq(senderNewBalance3, senderOldBalance3 - amount3);
    assertEq(receiverNewBalance3, receiverOldBalance3 + amount3);

    // Transfer 50,000 ether from addr7 to addr8
    uint256 amount4 = 50_000 ether;
    uint256 senderOldBalance4 = zfiToken.balanceOf(addr7);
    uint256 receiverOldBalance4 = zfiToken.balanceOf(addr8);

    vm.startPrank(addr7);
    zfiToken.transfer(addr8, amount4);
    vm.stopPrank();

    uint256 senderNewBalance4 = zfiToken.balanceOf(addr7);
    uint256 receiverNewBalance4 = zfiToken.balanceOf(addr8);

    assertEq(senderNewBalance4, senderOldBalance4 - amount4);
    assertEq(receiverNewBalance4, receiverOldBalance4 + amount4);
}

}
