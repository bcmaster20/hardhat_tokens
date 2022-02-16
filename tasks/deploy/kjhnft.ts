import { ContractFactory, BaseContract } from "ethers";
import { task } from "hardhat/config";
import { TaskArguments } from "hardhat/types";

task("deploy:KJHNFT").setAction(async function (taskArguments: TaskArguments, { ethers }) {
  const tokenFactory: ContractFactory = await ethers.getContractFactory("KJHNFTToken");
  const contract: BaseContract = <BaseContract>await tokenFactory.deploy();
  await contract.deployed();
  console.log("KJHNFT deployed to: ", contract.address);
});
