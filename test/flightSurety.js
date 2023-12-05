const Test = require("../config/testConfig.js");

contract("Flight Surety Tests", async accounts => {
  let config;
  before("setup contract", async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(
      config.flightSuretyApp.address
    );
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) should register first airline when data contract is deployed.`, async function () {
    const result = await config.flightSuretyData.getAirline(
      config.firstAirline
    );
    assert.equal(result[0], true, "First airline not registered.");
  });

  it(`(multiparty) has correct initial isOperational() value`, async function () {
    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

    status = await config.flightSuretyApp.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");
  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {
    // Ensure that access is denied for non-Contract Owner account
    let accessDenied = false;
    try {
      await config.flightSuretyData.setOperatingStatus(false, {
        from: accounts[2],
      });
    } catch (e) {
      accessDenied = true;
    }
    assert.equal(accessDenied, true, "Access not restricted to Contract Owner");

    try {
      await config.flightSuretyApp.setOperational({
        from: accounts[2],
      });
    } catch (e) {
      accessDenied = true;
    }
    assert.equal(accessDenied, true, "Access not restricted to Contract Owner");

    try {
      await config.flightSuretyApp.setNonOperational({
        from: accounts[2],
      });
    } catch (e) {
      accessDenied = true;
    }
    assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {
    // Ensure that access is allowed for Contract Owner account
    let accessDenied = false;
    try {
      await config.flightSuretyData.setOperatingStatus(true);
    } catch (e) {
      accessDenied = true;
    }
    assert.equal(
      accessDenied,
      false,
      "Access not restricted to Contract Owner"
    );
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {
    let reverted = false;
    try {
      await config.flightSuretyData.setOperatingStatus(false);
      const { success, votes } = await config.flightSuretyApp.registerAirline(
        accounts[2],
        {
          from: config.firstAirline,
        }
      );
    } catch (e) {
      // console.log(e.message);
      reverted = true;
      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);
    }

    assert.equal(reverted, true, "Access not blocked for requireIsOperational");
  });

  it("(airline) cannot register an Airline using registerAirline() if it is not funded", async () => {
    // ARRANGE
    const newAirline = accounts[2];

    // ACT
    try {
      await config.flightSuretyApp.registerAirline(newAirline, "Second", {
        from: accounts[1],
      });
    } catch (e) {
      // console.error(e.message);
    }
    const result = await config.flightSuretyData.getAirline(newAirline);

    // ASSERT
    assert.equal(
      result[0],
      false,
      "Airline should not be able to register another airline if it hasn't provided funding"
    );
  });

  it("(airline) can provide funds to contract", async () => {
    // ARRANGE
    const initialBalance = web3.utils.toBN(
      await web3.eth.getBalance(config.flightSuretyData.address)
    );
    const bn10 = web3.utils.toWei(web3.utils.toBN(10), "ether");
    // ACT
    try {
      await config.flightSuretyData.fund(config.firstAirline, {
        from: config.firstAirline,
        value: bn10,
      });
    } catch (e) {
      console.log(e);
      assert(false, `An error occured during tx: ${e.message}`);
    }
    const finalBalance = web3.utils.toBN(
      await web3.eth.getBalance(config.flightSuretyData.address)
    );
    const result = await config.flightSuretyData.getAirline(accounts[1]);
    const balance = result[1];

    // ASSERT
    assert(
      bn10.lte(finalBalance.sub(initialBalance)),
      "Registered Airline could not provid funding."
    );
    assert(
      balance.eq(bn10),
      "Registered Airline did not receive funding in data Contract."
    );
  });

  it("(airline) can register an Airline using registerAirline() if it is funded", async () => {
    // ARRANGE
    const newAirline = accounts[2];

    // ACT
    try {
      await config.flightSuretyApp.registerAirline(newAirline, "Second", {
        from: config.firstAirline,
      });
    } catch (e) {
      assert(false, `An error occured during tx: ${e.message}`);
    }
    const result = await config.flightSuretyData.getAirline(newAirline);

    // ASSERT
    assert.equal(
      result[0],
      true,
      "Airline should not be able to register another airline if it hasn't provided funding"
    );
  });

  it("(multiparty) can register up to 4 Airlines without consensus", async () => {
    // ARRANGE
    for (let idx of Array(2).keys()) {
      idx += 3; //accounts[0] is owner, 1 and 2 are registered
      const newAirline = accounts[idx];
      // ACT
      try {
        await config.flightSuretyApp.registerAirline(
          newAirline,
          `Other-${idx}`,
          {
            from: config.firstAirline,
          }
        );
      } catch (e) {
        assert(false, `An error occured during tx: ${e.message}`);
      }
      const result = await config.flightSuretyData.getAirline(newAirline);

      // ASSERT
      assert.equal(
        result[0],
        true,
        "Could not register 4 airlines without consensus"
      );
    }
  });

  it("(airline) can provide funds to contract for registered airlines to be able to vote", async () => {
    for (let idx of Array(3).keys()) {
      idx += 2;
      // ARRANGE
      const initialBalance = await web3.eth.getBalance(
        config.flightSuretyData.address
      );

      // ACT
      try {
        await config.flightSuretyData.fund(accounts[idx], {
          from: accounts[idx],
          value: web3.utils.toWei("10", "ether"),
        });
      } catch (e) {
        assert(false, `An error occured during tx: ${e.message}`);
      }
      const finalBalance = await web3.eth.getBalance(
        config.flightSuretyData.address
      );
      const result = await config.flightSuretyData.getAirline(accounts[idx]);
      const balance = result[1];

      // ASSERT
      assert(
        finalBalance - initialBalance >= web3.utils.toWei("10", "ether"),
        "Registered Airline could not provid funding."
      );
      assert(
        balance == web3.utils.toWei("10", "ether"),
        "Registered Airline did not receive funding in data Contract."
      );
    }
  });

  it("(multiparty) can register an Airline using consensus", async () => {
    // ARRANGE
    const newAirline = accounts[5]; //accounts[4] is the last one registered
    // 2-of-4 needed => 50%
    for (let idx of Array(2).keys()) {
      idx++;
      // ACT
      try {
        await config.flightSuretyApp.registerAirline(
          newAirline,
          `Other-${idx}`,
          {
            from: accounts[idx], //accounts[0] is owner
          }
        );
      } catch (e) {
        assert(false, `An error occured during tx: ${e.message}`);
      }

      const result = await config.flightSuretyData.getAirline(newAirline);

      if (idx < 2) {
        // ASSERT
        assert.equal(
          result[0],
          false,
          "More than 4 Airlines. Could register another airline without consensus"
        );
      } else {
        assert.equal(
          result[0],
          true,
          "More than 4 Airlines. Could not register another airline with consensus"
        );
      }
    }
  });

  it("(airline) cannot vote to register an Airline twice", async () => {
    // ARRANGE
    const newAirline = accounts[6]; //accounts[5] is the last one registered
    const accNum = 1;
    let reverted;
    for (let idx of Array(2).keys()) {
      // ACT
      try {
        await config.flightSuretyApp.registerAirline(
          newAirline,
          `Other-${idx}`,
          {
            from: accounts[accNum], //accounts[0] is owner
          }
        );
        if (idx > 0) {
          // Should throw on second pass, just being sure.
          assert(false, "Airline voted twice for the same candidate.");
        }
      } catch (e) {
        e.message === "Airline voted twice for the same candidate."
          ? (reverted = true)
          : (reverted = false);
        // console.log(e.message);
      }
    }
    // ASSERT
    assert.equal(reverted, true, "Airline voted twice for the same candidate.");
  });

  it("(passenger) can buy insurance for up to 1 ETH", async () => {
    // ARRANGE
    const passenger = accounts[6];
    const airline = accounts[1];
    const flight = "LA-3333";
    const dtStr = "05/02/2023";
    const [d, m, y] = dtStr.split(/-|\//);
    const date = new Date(y, m - 1, d);
    const timestamp = date.getTime() / 1000;
    const val = web3.utils.toWei("0.5", "ether");
    // ACT
    try {
      await config.flightSuretyApp.buy(passenger, airline, flight, timestamp, {
        from: passenger,
        value: val,
      });
    } catch (e) {
      assert(false, `An error occured during tx: ${e.message}`);
    }
    const key = await config.flightSuretyApp.getInsuranceKey(
      passenger,
      airline,
      flight,
      timestamp
    );
    const result = await config.flightSuretyData.getInsuranceValue(key);

    // ASSERT
    assert.equal(result.gte(val), true, "Could not buy insurance.");
  });

  it("(passenger) cannot buy insurance for more than 1 ETH", async () => {
    // ARRANGE
    const passenger = accounts[7];
    const airline = accounts[1];
    const flight = "LA-3333";
    const dtStr = "05/02/2023";
    const [d, m, y] = dtStr.split(/-|\//);
    const date = new Date(y, m - 1, d);
    const timestamp = date.getTime() / 1000;
    const val = web3.utils.toWei("1.001", "ether");
    // ACT
    let reverted;
    try {
      await config.flightSuretyApp.buy(passenger, airline, flight, timestamp, {
        from: passenger,
        value: val,
      });
    } catch (e) {
      reverted = true;
    }
    const key = await config.flightSuretyApp.getInsuranceKey(
      passenger,
      airline,
      flight,
      timestamp
    );
    const result = await config.flightSuretyData.getInsuranceValue(key);

    // ASSERT
    assert.equal(result, 0, "Bought insurance for more than 1 ETH.");
    assert.equal(reverted, true, "Bought insurance for more than 1 ETH.");
  });
});
