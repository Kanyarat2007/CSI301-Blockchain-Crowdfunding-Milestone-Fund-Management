// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract InnovateFund {
    address public immutable admin;
    uint256 public campaignCount;
    uint256 private unlocked = 1;
    modifier nonReentrant() { require(unlocked == 1, "Reentrancy"); unlocked = 2; _; unlocked = 1; }

    struct Campaign {
        address payable creator;
        string title;
        string description;
        uint256 goal;
        uint256 deadline;
        uint256 raised;
        uint256 released;
        uint256 refunded;
        uint256 milestoneCount;
    }
    struct Milestone {
        string title;
        uint256 amount;
        string evidence;
        uint256 approvals;
        uint256 rejections;
        uint256 votingPowerSnapshot;
        uint256 voteDeadline;
        bool requested;
        bool paid;
    }
    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(uint256 => Milestone)) private milestones;
    mapping(uint256 => mapping(address => uint256)) public contributions;
    mapping(uint256 => mapping(uint256 => mapping(address => bool))) public hasVoted;
    mapping(uint256 => uint256) public contributorsCount;
    mapping(uint256 => mapping(address => bool)) private seenContributor;
    event CampaignCreated(uint256 indexed id, address indexed creator, string title, uint256 goal);
    event Contributed(uint256 indexed id, address indexed contributor, uint256 amount);
    event ReleaseRequested(uint256 indexed id, uint256 indexed milestone, string evidence);
    event Voted(uint256 indexed id, uint256 indexed milestone, address indexed voter, bool approve, uint256 weight);
    event FundsReleased(uint256 indexed id, uint256 indexed milestone, uint256 amount);
    event Refunded(uint256 indexed id, address indexed backer, uint256 amount);

    constructor() { admin = msg.sender; }

    function createCampaign(string calldata title, string calldata description, uint256 goal, uint256 durationSeconds, string[] calldata titles, uint256[] calldata amounts) external returns (uint256 id) {
        require(bytes(title).length > 0 && goal > 0 && durationSeconds > 0, "Invalid campaign");
        require(titles.length > 0 && titles.length == amounts.length && titles.length <= 20, "Invalid milestones");
        uint256 total;
        for (uint256 i; i < amounts.length; i++) {
            require(amounts[i] > 0 && bytes(titles[i]).length > 0, "Invalid milestone");
            total += amounts[i];
        }
        require(total <= goal, "Milestones exceed goal");
        id = ++campaignCount;
        Campaign storage c = campaigns[id];
        c.creator = payable(msg.sender); c.title = title; c.description = description;
        c.goal = goal; c.deadline = block.timestamp + durationSeconds; c.milestoneCount = titles.length;
        for (uint256 i; i < titles.length; i++) {
            milestones[id][i].title = titles[i]; milestones[id][i].amount = amounts[i];
        }
        emit CampaignCreated(id, msg.sender, title, goal);
    }
    function contribute(uint256 id) external payable {
        Campaign storage c = campaigns[id];
        require(c.creator != address(0) && block.timestamp < c.deadline, "Funding closed");
        require(msg.value > 0, "Zero contribution");
        if (!seenContributor[id][msg.sender]) { seenContributor[id][msg.sender] = true; contributorsCount[id]++; }
        contributions[id][msg.sender] += msg.value; c.raised += msg.value;
        emit Contributed(id, msg.sender, msg.value);
    }
    function requestRelease(uint256 id, uint256 index, string calldata evidence) external {
        Campaign storage c = campaigns[id];
        require(msg.sender == c.creator, "Creator only");
        require(block.timestamp >= c.deadline && c.raised >= c.goal, "Funding not successful");
        require(index < c.milestoneCount && bytes(evidence).length > 0, "Invalid request");
        require(index == 0 || milestones[id][index - 1].paid, "Complete previous milestone");
        Milestone storage m = milestones[id][index];
        require(!m.requested && !m.paid, "Already requested");
        require(c.raised - c.released - c.refunded >= m.amount, "Insufficient escrow");
        m.requested = true; m.evidence = evidence;
        m.votingPowerSnapshot = c.raised;
        m.voteDeadline = block.timestamp + 3 days;
        emit ReleaseRequested(id, index, evidence);
    }
    function vote(uint256 id, uint256 index, bool approve) external {
        Campaign storage c = campaigns[id];
        require(index < c.milestoneCount, "Unknown milestone");
        Milestone storage m = milestones[id][index];
        require(m.requested && !m.paid && block.timestamp < m.voteDeadline, "Voting closed");
        require(!hasVoted[id][index][msg.sender], "Already voted");
        uint256 weight = contributions[id][msg.sender];
        require(weight > 0, "Backers only");
        hasVoted[id][index][msg.sender] = true;
        if (approve) m.approvals += weight; else m.rejections += weight;
        emit Voted(id, index, msg.sender, approve, weight);
    }
    function release(uint256 id, uint256 index) external nonReentrant {
        Campaign storage c = campaigns[id];
        require(index < c.milestoneCount, "Unknown milestone");
        Milestone storage m = milestones[id][index];
        require(m.requested && !m.paid, "Not releasable");
        require(block.timestamp >= m.voteDeadline, "Voting active");
        require(m.approvals > m.votingPowerSnapshot / 2, "Majority not reached");
        require(c.raised - c.released - c.refunded >= m.amount, "Insufficient escrow");
        m.paid = true; c.released += m.amount;
        (bool ok,) = c.creator.call{value:m.amount}(""); require(ok, "Transfer failed");
        emit FundsReleased(id, index, m.amount);
    }
    function refund(uint256 id) external nonReentrant {
        Campaign storage c = campaigns[id];
        require(c.creator != address(0) && block.timestamp >= c.deadline && c.raised < c.goal, "Refund unavailable");
        uint256 amount = contributions[id][msg.sender]; require(amount > 0, "Nothing to refund");
        contributions[id][msg.sender] = 0; c.refunded += amount;
        (bool ok,) = payable(msg.sender).call{value:amount}(""); require(ok, "Refund failed");
        emit Refunded(id, msg.sender, amount);
    }
    function getMilestone(uint256 id, uint256 index) external view returns (Milestone memory) {
        require(index < campaigns[id].milestoneCount, "Unknown milestone"); return milestones[id][index];
    }
}
