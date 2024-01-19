const main = async () => {
  const deployedContract = await ethers.deployContract("AirDrop", ["0xeE1E724fc458088744538337EC98b1f4fec1B9b7"]);

  await deployedContract.waitForDeployment();

  console.log("CoinSpace Contract Address:", await deployedContract.getAddress());
};
main();
