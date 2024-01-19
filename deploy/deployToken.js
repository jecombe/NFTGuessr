const main = async () => {
  const deployedContract = await ethers.deployContract("CoinSpace", [
    "0x77eD6de7fb3Ceda55C1a16508236d833e220eF06",
    "0xe58BA13DE030b28CCFEE72BCd76edE0750513C52",
  ]);

  await deployedContract.waitForDeployment();

  console.log("CoinSpace Contract Address:", await deployedContract.getAddress());
};
main();
