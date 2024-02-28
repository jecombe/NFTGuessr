const main = async () => {
  const deployedContract = await ethers.deployContract("SpaceCoin", [
    "0xC2Ac9f6D39a6929D995298C9c16a2af8821DB1F1",
    "0x0dCBA36F309A7E08F7C8179f5DbA7a145B16605a",
  ]);

  await deployedContract.waitForDeployment();

  console.log("SpaceCoin Contract Address:", await deployedContract.getAddress());
};
main();
