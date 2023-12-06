pragma solidity ^0.4.24;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner; // Account used to deploy contract
    bool private operational = true; // Blocks all state changes throughout the contract if false

    struct Airline {
        bool isRegistered;
        uint256 funding;
        uint256 votes;
        string name;
    }

    mapping(address => bool) private authorizedCallers;

    mapping(address => Airline) private airlines;
    address[] private airlinesRegistered;

    // struct Passenger {
    //     address wallet;
    //     uint256 funding;
    // }

    // mapping(address => Passenger) private passengers;

    uint64 private constant MAX_INSURANCE = 1 ether;

    mapping(bytes32 => uint256) private insurance;
    mapping(bytes32 => uint256) private credit;

    event FundedAirline(address airline, uint256 funds);

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    /**
     * @dev Constructor
     *      The deploying account becomes contractOwner
     */
    constructor(address firstAirline) public {
        contractOwner = msg.sender;
        // First one is on the house..
        airlines[firstAirline] = Airline({
            isRegistered: true,
            funding: 0,
            votes: 0,
            name: "First Airline"
        });
        airlinesRegistered.push(firstAirline);
    }

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
        require(operational, "Contract is currently not operational");
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
     * @dev Modifier that requires the "ContractOwner" account to be the function caller
     */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireIsCallerAuthorized() {
        require(authorizedCallers[msg.sender], "Contract is not authorized.");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
     * @dev Get operating status of contract
     *
     * @return A bool that is the current operating status
     */
    function isOperational() public view returns (bool) {
        return operational;
    }

    /**
     * @dev Sets contract operations on/off
     *
     * When operational mode is disabled, all write transactions except for this one will fail
     */
    function setOperatingStatus(bool mode) external requireContractOwner {
        operational = mode;
    }

    function isCallerAuthorized(address account) public view returns (bool) {
        return authorizedCallers[account];
    }

    function authorizeCaller(
        address contractAddress
    ) external requireContractOwner requireIsOperational {
        authorizedCallers[contractAddress] = true;
    }

    function deauthorizeCaller(
        address contractAddress
    ) external requireContractOwner requireIsOperational {
        delete authorizedCallers[contractAddress];
    }

    function getRegisteredAirlines()
        external
        view
        requireIsOperational
        returns (address[] memory)
    {
        return airlinesRegistered;
    }

    function getAirline(
        address account
    )
        public
        view
        requireIsOperational
        returns (bool, uint256, uint256, string)
    {
        Airline memory airline = airlines[account];
        return (
            airline.isRegistered,
            airline.funding,
            airline.votes,
            airline.name
        );
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     
     */
    function registerAirline(
        address account,
        uint256 _votes,
        string _name
    ) external requireIsCallerAuthorized requireIsOperational {
        require(
            !airlines[account].isRegistered,
            "Airline is already registered."
        );
        airlines[account] = Airline({
            isRegistered: false,
            funding: 0,
            votes: _votes,
            name: _name
        });
    }

    function updateAirline(
        address account,
        bool _isRegistered,
        uint256 _votes
    ) external requireIsCallerAuthorized requireIsOperational {
        Airline storage airline = airlines[account];
        airline.isRegistered = _isRegistered;
        airline.votes = _votes;
        if (_isRegistered) {
            airlinesRegistered.push(account);
        }
    }

    /**
     * @dev Buy insurance for a flight
     *
     */
    function buy(
        bytes32 key,
        uint256 value
    ) external requireIsCallerAuthorized requireIsOperational {
        uint256 current = getInsuranceValue(key);
        // uint256 target in mapping defaults to 0
        insurance[key] = current.add(value);
    }

    function getInsuranceValue(
        bytes32 key
    )
        public
        view
        requireIsOperational
        requireIsCallerAuthorized
        returns (uint256)
    {
        return insurance[key];
    }

    /**
     *  @dev Credits payouts to insurees. Each insuree must request his own credit.
     */
    function creditInsurees(
        bytes32 key,
        uint256 value
    ) external requireIsCallerAuthorized requireIsOperational {
        // uint256 target in mapping defaults to 0
        insurance[key] = insurance[key].sub(value);
        credit[key] = credit[key].add(value);
    }

    function getCreditValue(
        bytes32 key
    ) public view requireIsOperational returns (uint256) {
        return credit[key];
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
     */
    function pay(
        address passenger,
        bytes32 key,
        uint256 value
    ) external requireIsCallerAuthorized requireIsOperational {
        // uint256 target in mapping defaults to 0
        credit[key] = credit[key].sub(value);
        address(passenger).transfer(value);
    }

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */
    function fund() public payable requireIsOperational {
        fund(msg.sender);
    }

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */
    function fund(address account) public payable requireIsOperational {
        require(
            airlines[account].isRegistered,
            "Airline must be registered to receive funds in this Contract."
        );
        airlines[account].funding = msg.value.add(airlines[account].funding);
        emit FundedAirline(account, msg.value);
    }

    function getFlightKey(
        address airline,
        string memory flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
     * @dev Fallback function for funding smart contract.
     *
     */
    function() external payable {
        require(msg.data.length == 0);
        fund(msg.sender);
    }
}
