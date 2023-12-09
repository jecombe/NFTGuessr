const main = async () => {
  const deployedContract = await ethers.deployContract("CoinSpace", ["0x54EA61879209739513Af2BC691F435084E290EEb"]);

  await deployedContract.waitForDeployment();

  console.log("CoinSpace Contract Address:", await deployedContract.getAddress());
};
main();
