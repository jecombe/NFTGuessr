const main = async () => {
  const deployedContract = await ethers.deployContract("SpaceCoin", [
    "0x01A9189f4E3cD0BDE05A8125ccF87bD506343CA5",
    "0x389AC46d3019d1f1BaAB9f1752084e28Ac42C042",
  ]);

  await deployedContract.waitForDeployment();

  console.log("SpaceCoin Contract Address:", await deployedContract.getAddress());
};
main();
