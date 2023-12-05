import DOM from "./dom";
import Contract from "./contract";
import "./flightsurety.css";

(async () => {
  let result = null;

  let contract = new Contract("localhost", () => {
    // Read transaction
    contract.isOperational((error, result) => {
      display("Operational Status", "Check if contract is operational", [
        { label: "Operational Status", error: error, value: result },
      ]);
    });

    // User-submitted transaction
    DOM.elid("submit-oracle").addEventListener("click", () => {
      const airline = DOM.elid("flightStatusOption").value;
      const sel = DOM.elid("flightStatusOption");
      var flight = sel.options[sel.selectedIndex].text;
      const ts = DOM.elid("flightStatusTimestamp").value;
      const [m, d, y] = ts.split(/-|\//);
      const date = new Date(y, m - 1, d);
      const timestamp = date.getTime();
      // Write transaction
      contract.fetchFlightStatus(
        airline,
        flight,
        timestamp,
        (error, result) => {
          display("Oracles", "Trigger oracles", [
            {
              label: "Fetch Flight Status",
              error: error,
              value: result.flight + " " + result.timestamp,
            },
          ]);
        }
      );
    });

    // Register Airline
    DOM.elid("submit-airline").addEventListener("click", () => {
      const airlineAddress = DOM.elid("airline-address").value;
      const airlineName = DOM.elid("airline-name").value;
      contract.registerAirline(airlineAddress, airlineName, (error, result) => {
        display("Airline", "Airline Registration", [
          {
            label: "Registered Airline",
            error: error,
            value: result.airlineName,
          },
        ]);
      });
    });

    // Fund Airline
    DOM.elid("submit-funds").addEventListener("click", () => {
      const airlineFunds = DOM.elid("airline-funds").value;
      contract.fundAirline(airlineFunds, (error, payload) => {
        display("Airline", "Airline Funding", [
          {
            label: "Funded Airline",
            error: error,
            value: `Sent ${payload.amount} ETH to ${payload.fundsTo}. Balance is now ${payload.balance}.`,
          },
        ]);
      });
    });

    // Buy insurance
    DOM.elid("buy-insurance").addEventListener("click", () => {
      const airline = DOM.elid("buyInsuranceOption").value;
      const sel = DOM.elid("buyInsuranceOption");
      var flight = sel.options[sel.selectedIndex].text;
      const val = DOM.elid("buyInsuranceValue").value;
      const ts = DOM.elid("buyInsuranceTimestamp").value;
      const [m, d, y] = ts.split(/-|\//);
      const date = new Date(y, m - 1, d);
      const timestamp = date.getTime();
      console.log(airline, flight, val, timestamp);
      contract.buyInsurance(
        airline,
        flight,
        timestamp,
        val,
        (error, payload) => {
          display("Insurance", "Buy Insurance", [
            {
              label: "Result",
              error: error,
              value: `Bought insurance of ${payload.amount} ETH for flight ${payload.flight}.`,
            },
          ]);
        }
      );
    });
  });
})();

function display(title, description, results) {
  let displayDiv = DOM.elid("display-wrapper");
  let section = DOM.section();
  section.appendChild(DOM.h2(title));
  section.appendChild(DOM.h5(description));
  results.map(result => {
    let row = section.appendChild(DOM.div({ className: "row" }));
    row.appendChild(DOM.div({ className: "col-sm-4 field" }, result.label));
    row.appendChild(
      DOM.div(
        { className: "col-sm-8 field-value" },
        result.error ? String(result.error) : String(result.value)
      )
    );
    section.appendChild(row);
  });
  displayDiv.append(section);
}

const updateAirlineDropdown = () => {};
