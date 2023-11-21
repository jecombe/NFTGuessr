const hre = require("hardhat");

async function main() {
  // Déployez le contrat
  const NftGuessr = await hre.ethers.getContractFactory("NftGuessr");
  const nftGuessr = await NftGuessr.deploy();
  await nftGuessr.deployed();

  // Appelez la fonction checkGps pour estimer le gaz
  const userLatitude = [5028933]; // Remplacez par une latitude valide
  const userLongitude = [421875]; // Remplacez par une longitude valide

  const estimateGas = await nftGuessr.estimateGas.checkGps(userLatitude, userLongitude);
  console.log("Estimation du Gaz :", estimateGas.toString());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
