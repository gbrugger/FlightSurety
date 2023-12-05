pragma solidity ^0.4.24;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner; // Account used to deploy contract

    // struct Flight {
    //     bool isRegistered;
    //     uint8 statusCode;
    //     uint256 updatedTimestamp;
    //     address airline;
    // }
    // mapping(bytes32 => Flight) private flights;
    FlightSuretyData flightSuretyData;

    // keccak256(Voted airline + voter airline) => already voted?
    mapping(bytes32 => bool) private approvedBy;
    uint8 private approvedCount = 0;
    uint8 private constant APPROVED_M_RATIO = 2;
    uint8 private constant CONSENSUS_THRESHOLD = 4;

    uint256 private constant MIN_FUNDING = 10 ether;

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
     * @dev Modifier that requires the "operational" boolean variable to be "true"
     *      This is used on all state changing functions to pause the contract in
     *      the event there is an issue that needs to be fixed
     */
    modifier requireIsOperational() {
        // Modify to call data contract's status
        require(isOperational(), "Contract is currently not operational");
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
     * @dev Modifier that requires the "ContractOwner" account to be the function caller
     */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireIsAirlineAllowed() {
        require(
            isAirlineAllowed(msg.sender),
            "Airline not allowed to participate."
        );
        _;
    }

    modifier requireDidNotVoteFor(address account) {
        bytes32 accounts = keccak256(abi.encode(account, msg.sender));
        require(
            !approvedBy[accounts],
            "Caller has already voted for this airline."
        );
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
     * @dev Contract constructor
     *
     */
    constructor(address dataContract) public {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(dataContract);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() public view returns (bool) {
        return flightSuretyData.isOperational(); // Modify to call data contract's status
    }

    // function setOperational() public requireContractOwner {
    //     flightSuretyData.setOperatingStatus(true);
    // }

    // function setNonOperational() public requireContractOwner {
    //     flightSuretyData.setOperatingStatus(false);
    // }

    function isAirlineAllowed(address airline) public view returns (bool) {
        (bool isRegistered, uint256 funding, , ) = flightSuretyData.getAirline(
            airline
        );
        require(isRegistered, "Airline is not registered.");
        require(funding >= MIN_FUNDING, "Airline is not funded.");
        return isRegistered;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
     * @dev Add an airline to the registration queue
     *
     *      Only existing airline may register a new airline (business rules in App contract)
     */
    function registerAirline(
        address account,
        string name
    )
        public
        requireIsAirlineAllowed
        requireDidNotVoteFor(account)
        returns (bool success, uint256 votes)
    {
        (bool isRegistered, , uint256 _votes, ) = flightSuretyData.getAirline(
            account
        );
        require(!isRegistered, "Airline already registered.");

        if (_votes == 0) {
            flightSuretyData.registerAirline(account, _votes, name);
        }

        uint256 registeredAirlines = flightSuretyData
            .getRegisteredAirlines()
            .length;
        if (registeredAirlines < CONSENSUS_THRESHOLD) {
            isRegistered = true;
        } else {
            // Register voters to ensure one account only votes once. Used by modifier.
            // Concatenates with voted for address and use as key to avoid loops in arrays.
            // The original values are irrecoverable, but unnecessary.
            bytes32 key = keccak256(abi.encodePacked(account, msg.sender));
            approvedBy[key] = true;
            _votes = _votes.add(1);
            if (
                registeredAirlines.mul(10).div(APPROVED_M_RATIO) <=
                _votes.mul(10)
            ) {
                isRegistered = true;
            }
        }
        flightSuretyData.updateAirline(account, isRegistered, _votes);
        return (isRegistered, _votes);
    }

    function getInsuranceKey(
        address passenger,
        address airline,
        string flight,
        uint256 timestamp
    ) public pure returns (bytes32) {
        return
            keccak256(abi.encodePacked(passenger, airline, flight, timestamp));
    }

    /**
     * @dev Buy insurance for a flight
     *
     */
    function buy(
        address passenger,
        address airline,
        string flight,
        uint256 timestamp
    ) external payable {
        require(
            (msg.value > 0 ether) && (msg.value <= 1 ether),
            "Invalid value for insurance. Max: Up to 1 ETH."
        );
        require(
            isAirlineAllowed(airline),
            "Airline not allowed to participate."
        );

        (, uint256 _funds, , ) = flightSuretyData.getAirline(airline);
        require(
            _funds.add(msg.value) >= getInsuranceValue(msg.value),
            "Airline does not have enough funds to honor payments."
        );

        bytes32 key = getInsuranceKey(passenger, airline, flight, timestamp);
        uint256 insuredValue = flightSuretyData.getInsuranceValue(key);
        // May add up to existing insurance, but up to 1 ETH
        require(
            insuredValue.add(msg.value) <= 1 ether,
            "Invalid value for insurance. Min: >0, Max: <=1 ETH."
        );
        // For Solidity 0.6+ the syntax to forward funds is:
        // address.function{value:msg.value}(arg1, arg2, arg3)
        // flightSuretyData.fund{value: msg.value}(airline);
        flightSuretyData.fund.value(msg.value)(airline);
        flightSuretyData.buy(key, msg.value);
    }

    // function airlineHasFunds(
    //     address airline,
    //     uint256 amount
    // ) internal view returns (bool) {

    // }

    /**
     * @dev Calculate the insurance result based on how much was paid.
     *
     */
    function getInsuranceValue(uint256 amount) internal pure returns (uint256) {
        return amount.mul(3).div(2);
    }

    /**
     * @dev Register a future flight for insuring.
     *
     */
    function registerFlight() external pure {}

    // Flight data persisted forever
    struct FlightStatus {
        bool hasStatus;
        uint8 status;
    }
    mapping(bytes32 => FlightStatus) flights;

    /**
     * @dev Called after oracle has updated flight status
     *
     */
    function processFlightStatus(
        address airline,
        string memory flight,
        uint256 timestamp,
        uint8 statusCode
    ) internal {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        flights[flightKey] = FlightStatus(true, statusCode);
    }

    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus(
        address airline,
        string flight,
        uint256 timestamp
    ) external {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(
            abi.encodePacked(index, airline, flight, timestamp)
        );
        oracleResponses[key] = ResponseInfo({
            requester: msg.sender,
            isOpen: true
        });

        emit OracleRequest(index, airline, flight, timestamp);
    }

    // region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;

    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;
    }

    // Track all registered oracles
    // Key = hash(index, flight, timestamp)
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester; // Account that requested status
        bool isOpen; // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses; // Mapping key is the status code reported
        // This lets us group responses and identify
        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 status
    );

    event OracleReport(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 status
    );

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp
    );

    // Register an oracle with the contract
    function registerOracle() external payable {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({isRegistered: true, indexes: indexes});
    }

    function getMyIndexes() external view returns (uint8[3]) {
        require(
            oracles[msg.sender].isRegistered,
            "Not registered as an oracle"
        );

        return oracles[msg.sender].indexes;
    }

    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse(
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp,
        uint8 statusCode
    ) external {
        require(
            (oracles[msg.sender].indexes[0] == index) ||
                (oracles[msg.sender].indexes[1] == index) ||
                (oracles[msg.sender].indexes[2] == index),
            "Index does not match oracle request"
        );

        bytes32 key = keccak256(
            abi.encodePacked(index, airline, flight, timestamp)
        );
        require(
            oracleResponses[key].isOpen,
            "Flight or timestamp does not match oracle request"
        );

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (
            oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES
        ) {
            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }

    function getFlightKey(
        address airline,
        string flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(address account) internal returns (uint8[3]) {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);

        indexes[1] = indexes[0];
        while (indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while ((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex(address account) internal returns (uint8) {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(
            uint256(
                keccak256(
                    abi.encodePacked(blockhash(block.number - nonce++), account)
                )
            ) % maxValue
        );

        if (nonce > 250) {
            nonce = 0; // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

    // endregion
}

interface FlightSuretyData {
    function isOperational() external view returns (bool);

    function setOperatingStatus(bool mode) external;

    function registerAirline(
        address account,
        uint256 _votes,
        string name
    ) external;

    function getRegisteredAirlines() external view returns (address[] memory);

    function getAirline(
        address account
    )
        external
        view
        returns (
            bool isRegistered,
            uint256 funding,
            uint256 votes,
            string name
        );

    function updateAirline(
        address account,
        bool _isRegistered,
        uint256 _votes
    ) external;

    function buy(bytes32 key, uint256 value) external payable;

    function fund(address account) external payable;

    function getInsuranceValue(bytes32 key) external view returns (uint256);
}
