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
        address account;
    }

    mapping(address => bool) private authorizedCallers;

    mapping(address => Airline) private airlines;
    Airline[] private airlinesRegistered;

    struct Passenger {
        address wallet;
        uint256 funding;
    }

    mapping(address => Passenger) private passengers;

    uint64 private constant MAX_INSURANCE = 1 ether;

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
            name: "First Airline",
            account: firstAirline
        });
        airlinesRegistered.push(airlines[firstAirline]);
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
        returns (Airline[] memory)
    {
        Airline[] memory result = new Airline[](airlinesRegistered.length);
        for (uint32 i = 0; i < airlinesRegistered.length; i++) {
            result[i] = airlinesRegistered[i];
        }
        return result;
    }

    function getAirline(
        address account
    ) public view requireIsOperational returns (bool, uint256, uint256) {
        Airline memory airline = airlines[account];
        return (airline.isRegistered, airline.funding, airline.votes);
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
            name: _name,
            account: account
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
            airlinesRegistered.push(airline);
            // airlinesRegistered = airlinesRegistered.add(1);
        }
    }

    /**
     * @dev Buy insurance for a flight
     *
     */
    function buy() external payable {}

    /**
     *  @dev Credits payouts to insurees
     */
    function creditInsurees() external pure {}

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
     */
    function pay() external pure {}

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */
    function fund() public payable requireIsOperational {
        require(
            airlines[msg.sender].isRegistered,
            "Airline must be registered to fund this Contract."
        );
        airlines[msg.sender].funding = msg.value.add(
            airlines[msg.sender].funding
        );
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
        fund();
    }
}
