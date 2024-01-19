const main = async () => {
  const deployedContract = await ethers.deployContract("AirDrop", ["0x77eD6de7fb3Ceda55C1a16508236d833e220eF06"]);

  await deployedContract.waitForDeployment();

  console.log("CoinSpace Contract Address:", await deployedContract.getAddress());
};
main();
