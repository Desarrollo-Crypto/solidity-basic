// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title CharityDAO
/// @notice The contract allows its members to contribute to the DAO. Members can initiate charity proposals which Stakeholders will have to vote on within a specified period of time. After that time has elapsed, the DAO contract will disburse the pooled funds.
/*
    - Users send Celo tokens to the DAO to become Contributors.
    - Contributors that have made 200 or more total contributions are automatically made Stakeholders.
    - Only a Stakeholder of the DAO can vote on proposals.
    - Only Stakeholders can create a new proposal.
    - A newly created proposal has an ending date, when voting will conclude.
    - Stakeholders can upvote or downvote a proposal.
    - Once a Proposal's expiry date passes, a Stakeholder then pays out the requested amount to the specified Charity.
 */
contract CharityDAO is ReentrancyGuard, AccessControl {

    /* ========== STRUCTS ========== */

    struct CharityProposal {
        uint256 id;
        uint256 amount;
        uint256 livePeriod;
        uint256 votesFor;
        uint256 votesAgainst;
        string description;
        bool votingPassed;
        bool paid;
        address payable charityAddress;
        address proposer;
        address paidBy;
    }

    /* ========== STATE VARIABLES ========== */
    
    bytes32 public constant CONTRIBUTOR_ROLE = keccak256("CONTRIBUTOR");
    bytes32 public constant STAKEHOLDER_ROLE = keccak256("STAKEHOLDER");
    uint32 constant minimumVotingPeriod = 1 weeks;

    uint256 numOfProposals;
    mapping(uint256 => CharityProposal) private charityProposals; // List of proposals in the DAO.
    mapping(address => uint256[]) private stakeholderVotes; // Maps the address of a Stakeholder to a list of the Proposals that address has voted on.
    mapping(address => uint256) private contributors; // Maps the Contributor addresses and the amounts they have sent into the DAO treasury.
    mapping(address => uint256) private stakeholders; // Maps the addresses and balances of Stakeholders.

    /* ========== EVENTS ========== */

    event ContributionReceived(address indexed fromAddress, uint256 amount);
    event NewCharityProposal(address indexed proposer, uint256 amount);
    event PaymentTransfered(
        address indexed stakeholder,
        address indexed charityAddress,
        uint256 amount
    );

    /* ========== CONSTRUCTOR ========== */
    
    constructor() {}

    /* ========== PUBLIC METHODS ========== */

    function createProposal(
        string calldata _description,
        address _charityAddress,
        uint256 _amount
    )
        external
        onlyStakeholder("Only stakeholders are allowed to create proposals")
    {
        uint256 proposalId = numOfProposals++;
        CharityProposal storage proposal = charityProposals[proposalId]; // Using the storage keyword to make sure the state variable is maintained. Then assign its reference to one of the buckets in the charityProposals mapping.
        proposal.id = proposalId;
        proposal.amount = _amount;
        proposal.livePeriod = block.timestamp + minimumVotingPeriod;
        proposal.description = _description;
        proposal.charityAddress = payable(_charityAddress);
        proposal.proposer = msg.sender;

        // Emiting event
        emit NewCharityProposal(msg.sender, _amount);
    }

    /// @notice Function that allows voting on proposals
    /// @param _proposalId Proposal identifier id
    /// @param _supportProposal True or False depending on whether the vote is in support or against the proposal
    function vote(
        uint256 _proposalId, 
        bool _supportProposal
    )
        external
        onlyStakeholder("Only stakeholders are allowed to vote")
    {
        CharityProposal storage charityProposal = charityProposals[_proposalId];

        votable(charityProposal);

        if (_supportProposal) charityProposal.votesFor++;
        else charityProposal.votesAgainst++;

        stakeholderVotes[msg.sender].push(charityProposal.id);
    }

    /// @notice Handles payment to the specified address after the voting period of the proposal has ended
    function payCharity(uint256 _proposalId) 
        external
        onlyStakeholder("Only stakeholders are allowed to make payments")
    {
        CharityProposal storage charityProposal = charityProposals[_proposalId];
        
        if (charityProposal.livePeriod > block.timestamp)
            revert("The proposal live period hasn't finished");
        if (charityProposal.paid)
            revert("Payment has been made to this charity");
        if (charityProposal.votesFor <= charityProposal.votesAgainst)
            revert("The proposal does not have the required amount of votes to pass");
        
        charityProposal.paid = true;
        charityProposal.paidBy = msg.sender;

        emit PaymentTransfered(msg.sender, charityProposal.charityAddress, charityProposal.amount);

        return charityProposal.charityAddress.transfer(charityProposal.amount);
    }

    /// @notice This is needed so the contract can receive contributions without throwing an error.
    receive() external payable {
        deposit(msg.value);
    }

    /// @notice This function adds a new Stakeholder to the DAO if the total contribution of the user is more than or equal to 5 ether.
    function contribute() public payable {
        deposit(msg.value);
    }

    /// @notice We are returning a list of all the proposals in the DAO here. 
    /// @dev Solidity doesn’t have iterators for the mapping type so we declare a fixed-size array, used the numOfProposals variable as the upper limit of our loop. For each iteration, we assign the proposal at the current index to the index in our fixed-size array then return the array. Essentially, this fetches our proposals and returns them as an array.
    function getProposals() public view returns (CharityProposal[] memory props) {
        props = new CharityProposal[](numOfProposals);

        for (uint256 index = 0; index < numOfProposals; index++) {
            props[index] = charityProposals[index];
        }
    }

    /// @notice function takes a proposal id as an argument to get the proposal from the mapping, then return the proposal.
    function getProposal(uint256 proposalId)
        public
        view
        returns (CharityProposal memory)
    {
        return charityProposals[proposalId];
    }

    /// @notice Gets and returns a list containing the id of all the proposals that a particular stakeholder has voted on.
    function getStakeholderVotes()
        public
        view
        onlyStakeholder("User is not a stakeholder")
        returns (uint256[] memory)
    {
        return stakeholderVotes[msg.sender];
    }

    /// @notice Return the total amount of contribution a stakeholder has contributed to the DAO.
    function getStakeholderBalance()
        public
        view
        onlyStakeholder("User is not a stakeholder")
        returns (uint256)
    {
        return stakeholders[msg.sender];
    }

    /// @notice This function returns true/false depending on whether the caller is a stakeholder or not.
    function isStakeholder() public view returns (bool) {
        return stakeholders[msg.sender] > 0;
    }

    function getContributorBalance()
        public
        view
        onlyContributor("User is not a contributor")
        returns (uint256)
    {
        return contributors[msg.sender];
    }

    function isContributor() public view returns (bool) {
        return contributors[msg.sender] > 0;
    }

    /* ========== PRIVATE METHODS ========== */

    /// @notice Method used to verify if a proposal can be voted on
    function votable(CharityProposal storage _charityProposal) private {
        if (
            _charityProposal.votingPassed ||
            _charityProposal.livePeriod <= block.timestamp
        ) {
            _charityProposal.votingPassed = true;
            revert("Voting period has passed on this proposal");
        }

        uint256[] memory tempVotes = stakeholderVotes[msg.sender];
        for (uint256 votes = 0; votes < tempVotes.length; votes++) {
            if (_charityProposal.id == tempVotes[votes])
                revert("This stakeholder already voted on this proposal");
        }
    }

    function deposit(uint256 _amount) internal {
        require(_amount > 0, "Amount must be greater than 0");

        if (!hasRole(STAKEHOLDER_ROLE, msg.sender)) {
            uint256 totalContributed = contributors[msg.sender] + _amount;
            if (totalContributed >= 5 ether) {
                stakeholders[msg.sender] = totalContributed;
                _setupRole(STAKEHOLDER_ROLE, msg.sender);                
            }
        }

        contributors[msg.sender] += _amount;
        _setupRole(CONTRIBUTOR_ROLE, msg.sender);

        emit ContributionReceived(msg.sender, _amount);
    }
    

    /* ========== MODIFIERS ========== */

    modifier onlyStakeholder(string memory message) {
        require(hasRole(STAKEHOLDER_ROLE, msg.sender), message);
        _;
    }

    modifier onlyContributor(string memory message) {
        require(hasRole(CONTRIBUTOR_ROLE, msg.sender), message);
        _;
    }

}

