import FlightSuretyApp from "../../build/contracts/FlightSuretyApp.json";
import FlightSuretyData from "../../build/contracts/FlightSuretyData.json";
import Config from "./config.json";
import Web3 from "web3";

export default class Contract {
  constructor(network, callback) {
    this.config = Config[network];
    this.web3Init();
    this.flightSuretyApp = new this.web3.eth.Contract(
      FlightSuretyApp.abi,
      this.config.appAddress
    );
    this.flightSuretyData = new this.web3.eth.Contract(
      FlightSuretyData.abi,
      this.config.dataAddress
    );
    this.initialize(callback);
    this.owner = null;
    this.airlines = [];
    this.passengers = [];
  }

  web3Init = async () => {
    if (window.ethereum) {
      this.web3 = new Web3(window.ethereum);
    }
    // Legacy dapp browsers...
    else if (window.web3) {
      // Use MetaMask/Mist's provider.
      this.web3 = window.web3;
      console.log("Injected web3 detected.");
    }
    // Fallback to localhost; use dev console port by default...
    else {
      const provider = new Web3.providers.HttpProvider(this.config.url);
      this.web3 = new Web3(provider);
      console.log("No web3 instance injected, using Local web3.");
    }
    try {
      const accounts = await this.web3.eth.getAccounts();
      console.log(accounts.length > 0 ? "Connected." : "NOT Connected;");
      this.owner = accounts[0];
      const authorized = await this.flightSuretyData.methods
        .isCallerAuthorized(this.config.appAddress)
        .call();
      if (!authorized)
        await this.flightSuretyData.methods
          .authorizeCaller(this.config.appAddress)
          .send({ from: this.owner });

      this.flightSuretyData.events.FundedAirline((err, response) =>
        console.log(response)
      );
    } catch (error) {
      console.error(error);
    }
  };

  initialize(callback) {
    const self = this;
    self.web3.eth.getAccounts(async (error, accts) => {
      let counter = 1;
      // Accounts 1 to 5 are airlines
      while (self.airlines.length < 5) {
        self.airlines.push(accts[counter++]);
      }

      // Accounts 6 to 10 are passengers
      while (self.passengers.length < 5) {
        self.passengers.push(accts[counter++]);
      }

      callback();
    });
  }

  isOperational(callback) {
    let self = this;
    self.flightSuretyApp.methods
      .isOperational()
      .call({ from: self.owner }, callback);
  }

  fetchFlightStatus(airline, flight, timestamp, callback) {
    const self = this;
    timestamp /= 1000;
    const payload = {
      airline: airline,
      flight: flight,
      timestamp: timestamp,
    };
    self.flightSuretyApp.methods
      .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
      .send({ from: self.owner }, (error, result) => {
        callback(error, payload);
      });
  }

  registerAirline = async (airlineAddress, airlineName, callback) => {
    const self = this;
    let accounts = await self.web3.eth.getAccounts();
    const registrar = accounts[0];
    const payload = {
      airlineAddress: airlineAddress,
      airlineName: airlineName,
      registrar: registrar,
    };
    try {
      const { error, result } = await self.flightSuretyApp.methods
        .registerAirline(payload.airlineAddress, payload.airlineName)
        .send({ from: registrar });
      callback(error, payload);
    } catch (e) {
      callback(e.message, payload);
    }
  };

  fundAirline = async (amount, callback) => {
    const self = this;
    let accounts = await self.web3.eth.getAccounts();
    const fundsTo = accounts[0];
    const payload = {
      amount: amount,
      fundsTo: fundsTo,
    };
    try {
      const { error, resultHash } = await self.flightSuretyData.methods
        .fund()
        .send({
          from: payload.fundsTo,
          value: self.web3.utils.toWei(payload.amount, "ether"),
        });

      const result = await self.flightSuretyData.methods
        .getAirline(payload.fundsTo)
        .call();
      payload.balance = self.web3.utils.toBN(result[1]);

      callback(error, payload);
    } catch (e) {
      callback(e.message, payload);
    }
  };

  buyInsurance = async (airline, flight, timestamp, value, callback) => {
    const self = this;
    let accounts = await self.web3.eth.getAccounts();
    const passenger = accounts[0];
    timestamp /= 1000;
    const payload = {
      amount: value,
      flight: flight,
    };
    try {
      const { error, resultHash } = await self.flightSuretyApp.methods
        .buy(passenger, airline, flight, timestamp)
        .send({
          from: passenger,
          value: self.web3.utils.toWei(payload.amount, "ether"),
        });
      callback(error, payload);
    } catch (e) {
      console.error(e);
      callback(e.message, payload);
    }
  };
}
