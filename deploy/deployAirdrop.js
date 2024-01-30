const main = async () => {
  const deployedContract = await ethers.deployContract("AirDrop", ["0x01A9189f4E3cD0BDE05A8125ccF87bD506343CA5"]);

  await deployedContract.waitForDeployment();

  console.log("Airdrop Contract Address:", await deployedContract.getAddress());
};
main();
