import FlightSuretyApp from "../../build/contracts/FlightSuretyApp.json";
import FlightSuretyData from "../../build/contracts/FlightSuretyData.json";
import Config from "./config.json";
import Web3 from "web3";
import express from "express";

(async () => {
  const config = Config["localhost"];
  const ORACLES_COUNT = 100;

  const STATUS_CODE_UNKNOWN = 0;
  const STATUS_CODE_ON_TIME = 10;
  const STATUS_CODE_LATE_AIRLINE = 20;
  const STATUS_CODE_LATE_WEATHER = 30;
  const STATUS_CODE_LATE_TECHNICAL = 40;
  const STATUS_CODE_LATE_OTHER = 50;

  const web3 = new Web3(
    new Web3.providers.WebsocketProvider(config.url.replace("http", "ws"))
  );
  web3.eth.defaultAccount = web3.eth.accounts[0];
  const flightSuretyApp = new web3.eth.Contract(
    FlightSuretyApp.abi,
    config.appAddress
  );
  const flightSuretyData = new web3.eth.Contract(
    FlightSuretyData.abi,
    config.dataAddress
  );

  try {
    const accounts = await web3.eth.getAccounts();
    console.log(accounts.length > 0 ? "Connected." : "NOT Connected;");
    const owner = accounts[0];
    const authorized = await flightSuretyData.methods
      .isCallerAuthorized(config.appAddress)
      .call();
    if (!authorized)
      await flightSuretyData.methods
        .authorizeCaller(config.appAddress)
        .send({ from: owner });

    // Register Oracles
    console.log("REGISTER ORACLES");
    const fee = await flightSuretyApp.methods.REGISTRATION_FEE().call();
    for (let a of Array(ORACLES_COUNT).keys()) {
      try {
        await flightSuretyApp.methods.registerOracle().send({
          from: accounts[a],
          value: fee,
          gas: 20000000,
        });
      } catch (e) {
        console.log(e.message);
      }
    }
    console.log("REGISTER ORACLES END");

    // Watch for events
    flightSuretyData.events.FundedAirline((err, event) => console.log(event));

    flightSuretyApp.events.OracleRequest(async (error, event) => {
      if (error) console.log(error.message);
      console.log(event);
      for (let a = 0; a < ORACLES_COUNT; a++) {
        // Get oracle information
        const oracleIndexes = await flightSuretyApp.methods
          .getMyIndexes()
          .call({
            from: accounts[a],
          });
        // console.log("OracleIndexes", oracleIndexes);
        const flight = event.returnValues.flight;
        const timestamp = event.returnValues.timestamp;
        const airline = event.returnValues.airline;
        const STATUS = getRandomStatus();
        // console.log("STATUS", STATUS);
        for (let idx = 0; idx < 3; idx++) {
          try {
            // Submit a response...it will only be accepted if there is an Index match
            await flightSuretyApp.methods
              .submitOracleResponse(
                oracleIndexes[idx],
                airline,
                flight,
                timestamp,
                STATUS
              )
              .send({ from: accounts[a], gas: 20000000 });
          } catch (e) {
            // console.log("\nError", idx, oracleIndexes[idx], flight, timestamp);
          }
        }
      }
    });

    flightSuretyApp.events.FlightStatusInfo((error, event) => {
      if (error) console.log(error);
      console.log(event);
    });
  } catch (error) {
    console.error(error);
  }
})();

const app = express();
app.get("/api", (req, res) => {
  res.send({
    message: "An API for use with your Dapp!",
  });
});
const getRandomStatus = () => {
  // return 20;
  return (Math.round(Math.random() * 10) % 6) * 10;
};
export default app;
