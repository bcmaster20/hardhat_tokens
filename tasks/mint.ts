import { TransactionResponse } from "@ethersproject/providers";
import { ContractFactory, Contract } from "ethers";
import { task } from "hardhat/config";

task("mint", "KJHNFT mint", async (_taskArgs, { ethers }) => {
  const tokenFactory: ContractFactory = await ethers.getContractFactory("KJHNFTToken");
  const contract: Contract = <Contract>await tokenFactory.deploy();
  const ETHER_PUBLIC_KEY = "0x6155711b7a66B1473C9eFeF10150340E69ea48de";
  let tokenUris = [
    "https://ipfs.io/ipfs/QmPfdvsRSgmjbRzDdhz5KKL54F3vqszJj5gT7s8qb85qN2",
    "https://ipfs.io/ipfs/Qme3EAw5z7vhU1vzdkyN4uRDTFvsSNknTXtd7T4VNnDpYh",
    "https://ipfs.io/ipfs/Qma8WFHhur6RmsFBYfhnzJ4kU2LCbAHwD6gk9kL4xCMQkQ",
  ];

  for (let i = 0; i < tokenUris.length; i++) {
    const tr: TransactionResponse = await contract.mintNFT(ETHER_PUBLIC_KEY, tokenUris[i], { gasLimit: 500_000 });
    console.log("TX hash:", tr.hash);
  }
});
