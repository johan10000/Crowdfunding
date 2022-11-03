// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

/**
 * @title Crowdfunding
 * @custom:dev-run-script ./scripts/deploy.py
 */
contract Storage {

    /***************************************************** Variables *****************************************/

    // address of contributor
    // how much the contributor contributed
    mapping(address=>uint) contributors;

    // The manager of crowdfunding
    address public manager;

    // Mnimum contribution contributor is allowed to be part of this crowdfunding
    uint public minimumContribution;

    // Deadline of the crowdfunding
    uint public deadline;

    // Target amount to be raised to crowdfunding
    uint public target;

    // Current raised amount for crowdfunding
    uint public raisedAmount;

    // Total number of contributors till now
    uint public numberOfContributors;

    // Request to extract money from the project
    struct Request{
        string description; // Why do we want to extract money, for ex., environment protection, surgery, etc
        address payable recipient; // For whom are we extracting the money
        uint value; // How much money are we extracting
        bool completed; // 
        uint numberOfVoters; // 50% and more voters have to vote for this money to be extracted
        mapping(address=>bool) voters; // Voter and their votes
    }

    // The request number
    mapping(uint=>Request) requests;

    // Total number of requests till now
    uint public numRequests;

    /***************************************************** Variables *****************************************/

    constructor(uint _target, uint _deadline)
    {
        target = _target;
        deadline = block.timestamp+_deadline; // 10sec + 3600s = 1 hour from now is the deadline
        minimumContribution = 100 wei;
        manager = msg.sender;
    }

    function sendEth() public payable
    {
        require(block.timestamp < deadline, "Deadline has passed"); // The contributor can contribute only till the crowdfunding project is active
        require(msg.value >= minimumContribution, "Minimum contribution is not met");

        if(contributors[msg.sender]==0) // to check if the contributor is a first time contributor
        {
            numberOfContributors++;
        }

        contributors[msg.sender] = contributors[msg.sender] + msg.value; // increment the amount of contribution the contributor has contributed
        raisedAmount = raisedAmount +msg.value; // increase the raised amount
    }

    function getContractBalance() public view returns(uint)
    {
        return address(this).balance;
    }

    function refund() public // In case the project is not completed within deadline, a contributor can ask for refund
    {
        require(raisedAmount < target && block.timestamp > deadline, "You are not eligible for refund");
        require(contributors[msg.sender] > 0, "You have not contributed anything");

        address payable user=payable(msg.sender); //  We have to make the caller address payable first to receive refund
        user.transfer(contributors[msg.sender]); // the smart contract refunds the amount this contributor has contributed
        contributors[msg.sender] = 0;
    }

    modifier onlyManager()
    {
        require(msg.sender == manager, "Only manager can call this function");
        _;
    }

    // function to create request to extract money
    function createRequests(string memory _description, address payable _recipient, uint _value) public onlyManager
    {
        // use storage if we have mapping inside struct
        Request storage newRequest = requests[numRequests]; // get the current request, which is empty currently
        numRequests++; // increment the total number of requests
        newRequest.description = _description; // fill what is this request for
        newRequest.recipient = _recipient; // fill who is this request for
        newRequest.value = _value; // fill how much are we extracting
        newRequest.completed = false; // currently this request is not completed, so fill it false
        newRequest.numberOfVoters = 0; // currently, since the request is not completed, and is just started, the number of voters are 0
    }

    // to extract money through request, 50% of voters should vote, we are getting vote here
    function voteRequest(uint _requestNo) public
    {
        require(contributors[msg.sender]>0, "You must be a contributor in the crowdfunding to vote");
        Request storage thisRequest = requests[_requestNo];
        require(thisRequest.voters[msg.sender] == false, "You have already voted"); // to avoid double counting of votes
        thisRequest.voters[msg.sender] = true;
        thisRequest.numberOfVoters++;
    }

    // when we want to extract money from the raised crowdfunding
    function makePayment(uint requestNo) public onlyManager
    {
        require(raisedAmount>target);
        Request storage thisRequest = requests[requestNo];
        require(thisRequest.completed == false, "Thee request has been already completed");
        require(thisRequest.numberOfVoters > numberOfContributors/2, "Majority do not support"); // 50%
        thisRequest.recipient.transfer(thisRequest.value);
        thisRequest.completed = true;
    }
}
