const main = async () => {
  const deployedContract = await ethers.deployContract("CoinSpace", [
    "0xeE1E724fc458088744538337EC98b1f4fec1B9b7",
    "0x94FdCfb03085C57fb9961e8408D176ee9574f19F",
  ]);

  await deployedContract.waitForDeployment();

  console.log("CoinSpace Contract Address:", await deployedContract.getAddress());
};
main();
