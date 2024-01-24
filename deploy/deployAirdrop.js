const main = async () => {
  const deployedContract = await ethers.deployContract("AirDrop", ["0x10e6C0DC13cc05Cb73A234e2c1A4E1894f48ba78"]);

  await deployedContract.waitForDeployment();

  console.log("Airdrop Contract Address:", await deployedContract.getAddress());
};
main();
