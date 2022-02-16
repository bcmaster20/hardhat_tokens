import { task } from "hardhat/config";
import { TaskArguments } from "hardhat/types";

import {BaseContract, ContractFactory} from "ethers";

task("deploy:Cd3dToken")
  .setAction(async function (taskArguments: TaskArguments, { ethers }) {
    const tokenFactory: ContractFactory = await ethers.getContractFactory("Cd3dToken");
    const contract: BaseContract = <BaseContract>await tokenFactory.deploy();
    await contract.deployed();
    console.log("Cd3dToken deployed to: ", contract.address);
  });
