var test = false;

const Deployer = artifacts.require("Deployer");
const BlockTimeProvider = artifacts.require("BlockTimeProvider");
const TimeProviderMock = artifacts.require("TimeProviderMock");

const ProtocolSettings = artifacts.require("ProtocolSettings")
const ProposalsManager = artifacts.require("ProposalsManager");
const GovToken = artifacts.require("GovToken");
const CreditToken = artifacts.require("CreditToken");
const CreditProvider = artifacts.require("CreditProvider");
const CollateralManager = artifacts.require("CollateralManager");

const OptionTokenFactory = artifacts.require("OptionTokenFactory");
const OptionsExchange = artifacts.require("OptionsExchange");
const Incentivized = artifacts.require("Incentivized");

const DEXFeedFactory = artifacts.require("DEXFeedFactory");

const LinearLiquidityPoolFactory = artifacts.require("LinearLiquidityPoolFactory");
const LinearAnySlopeInterpolator = artifacts.require("LinearAnySlopeInterpolator");
const YieldTracker = artifacts.require("YieldTracker");


const MockChainLinkFeed = artifacts.require("ChainlinkFeed");
const AggregatorV3Mock = artifacts.require("AggregatorV3Mock");
const UnderlyingVault = artifacts.require("UnderlyingVault");

const Stablecoin = artifacts.require("ERC20Mock");
//const UnderlyingToken = artifacts.require("ERC20Mock");
//const UnderlyingFeed = artifacts.require("EthFeedMock");
//const SwapRouter = artifacts.require("UniswapV2RouterMock");



module.exports = async function(deployer) {
  if (test) {
    await deployer.deploy(Deployer, "0x0000000000000000000000000000000000000000");
    await deployer.deploy(TimeProviderMock);
    await deployer.deploy(GovToken, "");
    await deployer.deploy(UnderlyingToken, 18);
    await deployer.deploy(UnderlyingFeed);
    await deployer.deploy(SwapRouter);
    await deployer.deploy(ProtocolSettings, true);
  } else {
    await deployer.deploy(Deployer, "0xe977757dA5fd73Ca3D2bA6b7B544bdF42bb2CBf6");
    //await deployer.deploy(GovToken, "0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa");
  }

  const d = await Deployer.at(Deployer.address);
  console.log("Deployer is at: "+ Deployer.address);


  const timeProvider = await deployer.deploy(BlockTimeProvider);
  console.log("timeProvider is at: "+ timeProvider.address);
  const settings = await deployer.deploy(ProtocolSettings, false);
  console.log("settings is at: "+ settings.address);
  const ct = await deployer.deploy(CreditToken);
  const pm = await deployer.deploy(ProposalsManager);
  const gt = await deployer.deploy(GovToken, "0x0000000000000000000000000000000000000000");
  const uv = await deployer.deploy(UnderlyingVault);
  const id = await deployer.deploy(Incentivized);
  const lasit = await deployer.deploy(LinearAnySlopeInterpolator);
  const yt = await deployer.deploy(YieldTracker);


  const creditProvider = await deployer.deploy(CreditProvider);
  console.log("creditProvider is at: "+ creditProvider.address);
  const otf = await deployer.deploy(OptionTokenFactory);
  const exchange = await deployer.deploy(OptionsExchange);
  console.log("exchange is at: "+ exchange.address);
  const poolFactory = await deployer.deploy(LinearLiquidityPoolFactory);
  console.log("poolFactory is at: "+ poolFactory.address);
  const dexFeedFactory = await deployer.deploy(DEXFeedFactory);
  console.log("dexFeedFactory is at: "+ dexFeedFactory.address);
  const collateralManager = await deployer.deploy(CollateralManager);

  
  if (test) {
    deployer.setContractAddress("TimeProvider", TimeProviderMock.address);
    await deployer.deploy(Stablecoin, 18);
    deployer.setContractAddress("StablecoinA", Stablecoin.address, false);
    await deployer.deploy(Stablecoin, 9);
    deployer.setContractAddress("StablecoinB", Stablecoin.address, false);
    await deployer.deploy(Stablecoin, 6);
    deployer.setContractAddress("StablecoinC", Stablecoin.address, false);
    deployer.setContractAddress("UnderlyingToken", UnderlyingToken.address, false);
    deployer.setContractAddress("UnderlyingFeed", UnderlyingFeed.address);
    deployer.setContractAddress("SwapRouter", SwapRouter.address);
  }

  const FakeDAI = await deployer.deploy(Stablecoin, 18);
  d.setContractAddress("FakeDAI", FakeDAI.address, false);
  const FakeUSDC = await deployer.deploy(Stablecoin, 6);
  d.setContractAddress("FakeUSDC", FakeUSDC.address, false);


  await d.setContractAddress("ProtocolSettings", settings.address);
  await d.setContractAddress("TimeProvider", timeProvider.address);
  await d.setContractAddress("CreditProvider", creditProvider.address);
  await d.addAlias("CreditIssuer", "CreditProvider");
  await d.setContractAddress("CreditToken", ct.address);
  await d.setContractAddress("ProposalsManager", pm.address);
  await d.setContractAddress("CollateralManager", collateralManager.address);
  await d.setContractAddress("OptionsExchange", exchange.address);
  await d.setContractAddress("OptionTokenFactory", otf.address);
  await d.setContractAddress("GovToken", gt.address); //MAY JUST USE THE EXISTING GOV TOKEN ADDR ON POLYGON MAINNET TO MAKE THINGS SIMPLE
  await d.setContractAddress("LinearLiquidityPoolFactory", poolFactory.address);
  await d.setContractAddress("DEXFeedFactory", dexFeedFactory.address);
  await d.setContractAddress("Interpolator", lasit.address);
  await d.setContractAddress("YieldTracker", yt.address);
  await d.setContractAddress("UnderlyingVault", uv.address);
  await d.setContractAddress("Incentivized", id.address);

  console.log("set contract address done");
  await d.deploy();
  

  console.log("deployer done");


  const timeProviderAddress = await d.getContractAddress("TimeProvider");
  console.log("timeProviderAddress is at: "+ timeProviderAddress);
  const ProtocolSettingsAddress = await d.getContractAddress("ProtocolSettings");
  console.log("ProtocolSettingsAddress is at: "+ ProtocolSettingsAddress);
  const CreditProviderAddress = await d.getContractAddress("CreditProvider");
  console.log("CreditProviderAddress is at: "+ CreditProviderAddress);
  const OptionsExchangeAddress = await d.getContractAddress("OptionsExchange");
  console.log("OptionsExchangeAddress is at: "+ OptionsExchangeAddress);
  const LinearLiquidityPoolFactoryAddress = await d.getContractAddress("LinearLiquidityPoolFactory");
  console.log("LinearLiquidityPoolFactoryAddress is at: "+ LinearLiquidityPoolFactoryAddress);
  const DEXFeedFactoryAddress = await d.getContractAddress("DEXFeedFactory");
  console.log("DEXFeedFactoryAddress is at: "+ DEXFeedFactoryAddress);
  const ProposalsManagerAddress = await d.getContractAddress("ProposalsManager");
  console.log("ProposalsManagerAddress is at: "+ ProposalsManagerAddress);
  const GovTokenAddress = await d.getContractAddress("GovToken");
  console.log("GovTokenAddress is at: "+ GovTokenAddress);
};