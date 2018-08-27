pragma solidity ^0.4.11;

import "tokens/eip20/EIP20Interface.sol";
import "./Parameterizer.sol";
import "plcrvoting/PLCRVoting.sol";
import "zeppelin/math/SafeMath.sol";

contract SingleRegistry {
    using SafeMath for uint;

    // ------
    // EVENTS
    // ------
    event _Application(bytes32 indexed listingHash, bytes32 indexed subjectHash, uint deposit, uint appEndDate, string data, address indexed applicant);
    event _Challenge(bytes32 indexed listingHash, uint challengeID, string data, uint commitEndDate, uint revealEndDate, address indexed challenger);
    event _ChallengeSubject(bytes32 indexed listingHash, bytes32 indexed subjectHash, uint challengeID, string data, uint commitEndDate, uint revealEndDate, address indexed challenger);
    event _Deposit(bytes32 indexed listingHash, bytes32 indexed subjectHash, uint added, uint newTotal, uint newSubjectTotal, address indexed owner);
    event _Withdrawal(bytes32 indexed listingHash, bytes32 indexed subjectHash, uint withdrew, uint newTotal, uint newSubjectTotal, address indexed owner);
    event _ApplicationWhitelisted(bytes32 indexed listingHash);
    event _ApplicationSubjectRemoved(bytes32 indexed listingHash, bytes32 indexed subjectHash);
    event _ListingSubjectRemoved(bytes32 indexed listingHash, bytes32 indexed subjectHash);
    event _SubjectListingWithdrawn(bytes32 indexed listingHash, bytes32 indexed subjectHash);
    event _TouchAndRemovedSubject(bytes32 indexed listingHash, bytes32 indexed subjectHash);

    event _ApplicationRemoved(bytes32 indexed listingHash);
    event _ListingRemoved(bytes32 indexed listingHash);
    event _ListingWithdrawn(bytes32 indexed listingHash);
    event _TouchAndRemoved(bytes32 indexed listingHash);

    event _ChallengeFailed(bytes32 indexed listingHash, uint indexed challengeID, uint rewardPool, uint totalTokens);
    event _ChallengeSucceeded(bytes32 indexed listingHash, uint indexed challengeID, uint rewardPool, uint totalTokens);

    // ---------------
    // STATE VARIABLES
    // ---------------
    address public owner;
    bytes32[] public subjects = [keccak256("Algebra"), keccak256("Chemistry")];

    struct Subject {
        uint subjectExpiry;            // Maps subject to expiry time
        bool subjectWhitelisted;       // Indicates subject registry status
        uint subjectUnstakedDeposit;   // Maps subject to the deposit amount        
    }

    struct Listing {
        uint applicationExpiry; // Expiration date of apply stage
        bool whitelisted;       // Indicates registry status
        address owner;          // Owner of Listing
        uint unstakedDeposit;   // Number of tokens in the listing not locked in a challenge
        uint challengeID;       // Corresponds to a PollID in PLCRVoting
        bytes32 subject;        // Applying subject

        mapping (bytes32 => Subject) subjects;  // Maps subjectHashes to associated subject data
    }

    struct Challenge {
        uint rewardPool;        // (remaining) Pool of tokens to be distributed to winning voters
        address challenger;     // Owner of Challenge
        bool resolved;          // Indication of if challenge is resolved
        uint stake;             // Number of tokens at stake for either party during challenge
        uint totalTokens;       // (remaining) Number of tokens used in voting by the winning side
        bool isSubject;         // Indication of if challenged subject list
        bytes32 subject;        // The current subject which is challenged
        mapping(address => bool) tokenClaims; // Indicates whether a voter has claimed a reward yet
    }

    // Maps challengeIDs to associated challenge data
    mapping(uint => Challenge) public challenges;

    // Maps listing Hahses to associcated listingHash data
    mapping(bytes32 => Listing) public listings;

    // Global Variables
    EIP20Interface public token;
    PLCRVoting public voting;
    Parameterizer public parameterizer;
    string public name;

    modifier restricted() {
        if (msg.sender == owner) _;
    }

    // ------------
    // CONSTRUCTOR:
    // ------------
    /**
    @dev Constructor        Sets the addresses for token, voting, and parameterizer
    @param _tokenAddr       Address of the TCR's intrinsic ERC20 token
    @param _plcrAddr        Address of a PLCR voting contract for the provided token
    @param _paramsAddr      Address of a Parameterizer contract
    */
    function SingleRegistry(
        address _tokenAddr,
        address _plcrAddr,
        address _paramsAddr,
        string _name
    ) public {
        owner = msg.sender;

        token = EIP20Interface(_tokenAddr);
        voting = PLCRVoting(_plcrAddr);
        parameterizer = Parameterizer(_paramsAddr);
        name = _name;
    }

    //
    // OWNER INTERFACE
    //
    function newSubject(string _subject) public restricted {
        // TODO: Implement this method

        bytes32 subjectName = keccak256(_subject);

        // Check if subject has already existed
        for (uint8 i = 0; i < subjects.length; i++) {
            require(subjects[i] != subjectName, "Subject existed");
        }

        // Add new subject
        subjects.push(subjectName);
    }

    //
    // PUBLISHER INTERFACE
    //

    /**
    @dev        Allows expert to start a subject. Takes tokens from expert and sets apply stage end time
     */
    function apply(bytes32 _listingHash, bytes32 _subjectHash, uint _amount, string _data) external {
        /* Allow registry to use the token */
        address sender = msg.sender;
        require(token.approve(this, listing.unstakedDeposit + _amount), "Couldn't approve token to this registry");

        // TODO: Check if subject is valid
        require(isValidSubject(_subjectHash), "This subject is not valid");

        // TODO: Check if subject is white listed
        require(!isSubjectWhitelisted(_listingHash, _subjectHash), "This listing subject has already existed");

        // TODO: Check number of deposit tokens
        require(_amount >= parameterizer.get("minDeposit"), "Number of depoisits is not enough");

        require(!appWasMade(_listingHash) && !subjectAppWasMade(_listingHash, _subjectHash), "This application was made");


        // TODO: Sets owner
        Listing storage listing = listings[_listingHash];
        listing.owner = sender;
        listing.subject = _subjectHash;

        // TODO: Sets apply stage end time
        listing.subjects[_subjectHash].subjectExpiry = block.timestamp.add(parameterizer.get("applyStageLen"));
        listing.subjects[_subjectHash].subjectUnstakedDeposit = _amount;

        listing.applicationExpiry = block.timestamp.add(parameterizer.get("applyStageLen"));
        listing.unstakedDeposit += _amount;

        // TODO: Transfers tokens from user to Registry contract
        require(token.transferFrom(listing.owner, this, _amount), "Couldn't transfer the token to the Registry");

        // TODO: Emit event
        emit _Application(_listingHash, _subjectHash, _amount, listing.subjects[_subjectHash].subjectExpiry, _data, sender);
    }

    /**
    @dev        Allows the owner of the listingHash to increaase their unstaked deposit
    */
    function deposit(bytes32 _listingHash, bytes32 _subjectHash, uint _amount) external {
        Listing storage listing = listings[_listingHash];

        require(listing.owner == msg.sender, "You don't have permission to run this function");

        listing.subjects[_subjectHash].subjectUnstakedDeposit += _amount;
        listing.unstakedDeposit += _amount;

        require(token.transferFrom(msg.sender, this, _amount), "Couldn't transfer the token to the Registry");

        emit _Deposit(_listingHash, _subjectHash, _amount, listing.unstakedDeposit, listing.subjects[_subjectHash].subjectUnstakedDeposit, msg.sender);
    }

    /**
    @dev        Allows the owner of a listing Hash to decrease their unstaked deposit
    */
    function withdraw(bytes32 _listingHash, bytes32 _subjectHash, uint _amount) external {
        Listing storage listing = listings[_listingHash];

        require(listing.owner == msg.sender, "You don't have permission to run this function");
        require(_amount <= listing.unstakedDeposit, "Don't have enough token to withdraw");
        require(_amount <= listing.subjects[_subjectHash].subjectUnstakedDeposit, "Don't have enough token of this subject to withdraw");

        require(listing.subjects[_subjectHash].subjectUnstakedDeposit - _amount >= parameterizer.get("minDeposit"), "The remaint tokens need to be greater than minDeposit");

        listing.unstakedDeposit -= _amount;
        listing.subjects[_subjectHash].subjectUnstakedDeposit -= _amount;

        require(token.transfer(msg.sender, _amount), "Couldn't transfer the token to the Registry");

        emit _Withdrawal(_listingHash, _subjectHash, _amount, listing.unstakedDeposit, listing.subjects[_subjectHash].subjectUnstakedDeposit, msg.sender);
    }

    /**
    @dev        Allows the owner of the listingHash to remove the subject from the white list
    */
    function exitSubject(bytes32 _listingHash, bytes32 _subjectHash) external {
        Listing storage listing = listings[_listingHash];

        require(msg.sender == listing.owner, "You don't have permission to run this function");
        require(isSubjectWhitelisted(_listingHash, _subjectHash), "This subject wasn't whitelisted");

        // Cannot exit during ongoing challenge
        require(listing.challengeID == 0 || challenges[listing.challengeID].resolved, "This listing is in the middle of a challenge session");

        // Remove listing subject & return tokens
        resetSubjectListing(_listingHash, _subjectHash);

        emit _SubjectListingWithdrawn(_listingHash, _subjectHash);
    }

    /**
    @dev        Allows the owner of the listingHash to remove the listingHash from the white list
    */
    function exit(bytes32 _listingHash) external {
        Listing storage listing = listings[_listingHash];

        require(msg.sender == listing.owner, "You don't have permission to run this function");
        require(isWhitelisted(_listingHash), "This listing wasn't whitelisted");

        // Cannot exit during ongoing challenge
        require(listing.challengeID == 0 || challenges[listing.challengeID].resolved, "This listing is in the middle of a challenge session");

        // Remove listingHash & return tokens
        resetListing(_listingHash);
        
        emit _ListingWithdrawn(_listingHash);
    }

    // -----------------------
    // TOKEN HOLDER INTERFACE:
    // -----------------------
    /**
    @dev                Starts a poll for a listingHash which is either in the apply stage or
                        already in the whitelist. Tokens are taken from the challenger and the
                        applicant's deposits are locked.
    @param _listingHash The listingHash being challenged, whether listed or in application
    @param _data        Extra data relevant to the challenge. Think IPFS hashes.
    */
    function challenge(bytes32 _listingHash, string _data) external returns (uint challengeID) {

        Listing storage listing = listings[_listingHash];
        uint deposit = parameterizer.get("minDeposit");

        /* Allow registry to use the token */
        require(token.approve(this, deposit));

        // Listing must be in apply stage or already on the whitelist
        require(appWasMade(_listingHash) || listing.whitelisted);
        // Prevent multiple challenges
        require(listing.challengeID == 0 || challenges[listing.challengeID].resolved);

        if (listing.unstakedDeposit < deposit) {
            // Not enough tokens, listingHash auto-delisted
            resetListing(_listingHash);
            _TouchAndRemoved(_listingHash);
            return 0;
        }

        // Starts poll
        uint pollID = voting.startPoll(
            parameterizer.get("voteQuorum"),
            parameterizer.get("commitStageLen"),
            parameterizer.get("revealStageLen")
        );

        challenges[pollID] = Challenge({
            challenger: msg.sender,
            rewardPool: ((100 - parameterizer.get("dispensationPct")) * deposit) / 100,
            stake: deposit,
            resolved: false,
            totalTokens: 0,
            isSubject: true,
            subject: 0x0
        });

        // Updates listingHash to store most recent challenge
        listing.challengeID = pollID;

        // Locks tokens for listingHash during challenge
        listing.unstakedDeposit -= deposit;

        // Takes tokens from challenger
        require(token.transferFrom(msg.sender, this, deposit));

        var (commitEndDate, revealEndDate,) = voting.pollMap(pollID);

        _Challenge(_listingHash, pollID, _data, commitEndDate, revealEndDate, msg.sender);
        return pollID;
    }

    function challengeSubject(bytes32 _listingHash, bytes32 _subjectHash, string _data) external returns (uint challengeID) {
        
        Listing storage listing = listings[_listingHash];
        uint deposit = parameterizer.get("minDeposit");

        /* Allow registry to use the token */
        require(token.approve(this, deposit), "Couldn't approve token to this registry");

        // TODO: Listing must be in apply stage or already on the whitelist
        require(
            subjectAppWasMade(_listingHash, _subjectHash) || listing.subjects[_subjectHash].subjectWhitelisted, "This application is not ready to be challenge"
            );

        // Prevent multiple challenges
        require(listing.challengeID == 0 || challenges[listing.challengeID].resolved, "This application is in the middle of another challenge");

        if (listing.subjects[_subjectHash].subjectUnstakedDeposit < deposit) {
            // TODO: Remove this subject
            resetSubjectListing(_listingHash, _subjectHash);
            emit _TouchAndRemovedSubject(_listingHash, _subjectHash);
            return 0;
        }

        // Starts poll
        uint pollID = voting.startPoll(
            parameterizer.get("voteQuorum"),
            parameterizer.get("commitStageLen"),
            parameterizer.get("revealStageLen")
        );

        challenges[pollID] = Challenge({
            challenger: msg.sender,
            rewardPool: ((100 - parameterizer.get("dispensationPct")) * deposit) / 100,
            stake: deposit,
            resolved: false,
            totalTokens: 0,
            isSubject: true,
            subject: _subjectHash
        });

        // Updates listingHash to store most recent challenge
        listing.challengeID = pollID;

        // Locks tokens for listingHash during challenge
        listing.subjects[_subjectHash].subjectUnstakedDeposit -= deposit;
        listing.unstakedDeposit -= deposit;

        // Takes tokens from challenger
        require(token.transferFrom(msg.sender, this, deposit), "Couldn't transfer token");

        var (commitEndDate, revealEndDate,) = voting.pollMap(pollID);

        emit _ChallengeSubject(_listingHash, _subjectHash, pollID, _data, commitEndDate, revealEndDate, msg.sender);

        return pollID;
    }

    /**
    @dev                Updates a listingHash's status from 'application' to 'listing' or resolves
                        a challenge if one exists.
    @param _listingHash The listingHash whose status is being updated
    */
    function updateStatus(bytes32 _listingHash) public {
        uint challengeID = listings[_listingHash].challengeID;
        bytes32 subjectHash = challenges[challengeID].subject != 0x0 ? challenges[challengeID].subject : listings[_listingHash].subject;

        if (canSubjectBeWhitelisted(_listingHash, subjectHash)) {
            whitelistSubject(_listingHash, subjectHash);
            whitelistApplication(_listingHash);
        } else if (challengeCanBeResolved(_listingHash)) {
            resolveChallenge(_listingHash);
        } else {
            revert("Couldn't update status of this listing");
        }
    }

    // ----------------
    // TOKEN FUNCTIONS:
    // ----------------

    // TODO: Implement functions for token here

    //
    // GETTERS
    //

    /**
    @dev                Determines whether the given listingHash be whitelisted.
    @param _listingHash The listingHash whose status is to be examined
    */
    function canSubjectBeWhitelisted(bytes32 _listingHash, bytes32 _subjectHash) view public returns (bool) {
        uint challengeID = listings[_listingHash].challengeID;

        bool wasMade = subjectAppWasMade(_listingHash, _subjectHash);
        bool isEnded = (listings[_listingHash].subjects[_subjectHash].subjectExpiry < now);
        bool whitelisted = isSubjectWhitelisted(_listingHash, _subjectHash);
        bool doneChallenged = (challengeID == 0 || challenges[challengeID].resolved == true);

        // Ensures that the application was made,
        // the application period has ended,
        // the listingHash can be whitelisted,
        // and either: the challengeID == 0, or the challenge has been resolved.
        
        if (
            wasMade
            &&
            isEnded
            &&
            !whitelisted
            &&
            doneChallenged
        ) {
            return true;
        }

        return false;
    }

    /**
    @dev                Returns true if the application/listingHash has an unresolved challenge
    @param _listingHash The listingHash whose status is to be examined
    */
    function challengeExists(bytes32 _listingHash) view public returns (bool) {
        uint challengeID = listings[_listingHash].challengeID;

        return (listings[_listingHash].challengeID > 0 && !challenges[challengeID].resolved);
    }

    /**
    @dev                Determines whether voting has concluded in a challenge for a given
                        listingHash. Throws if no challenge exists.
    @param _listingHash A listingHash with an unresolved challenge
    */
    function challengeCanBeResolved(bytes32 _listingHash) view public returns (bool) {
        uint challengeID = listings[_listingHash].challengeID;

        if (!challengeExists(_listingHash)) {
            return false;
        }

        return voting.pollEnded(challengeID);
    }

    /**
    @dev        Check if the subject is in the valid subject list
    */
    function isValidSubject(bytes32 _subject) view public returns (bool valid) {
        for (uint8 i = 0; i < subjects.length; i++) {
            if (subjects[i] == _subject) {
                return true;
            }
        }

        return false;
    }

    /**
    @dev        Check if the expert has already been listing in a subject
    */
    function isSubjectWhitelisted(bytes32 _listingHash, bytes32 _subjectHash) view public returns (bool whitelisted) {
        return listings[_listingHash].whitelisted && listings[_listingHash].subjects[_subjectHash].subjectWhitelisted;
    }

    /**
    @dev                Returns true if the provided listingHash is whitelisted
    @param _listingHash The listingHash whose status is to be examined
    */
    function isWhitelisted(bytes32 _listingHash) view public returns (bool whitelisted) {
        return listings[_listingHash].whitelisted;
    }

    /**
    @dev                Returns true if apply was called for this listingHash
    @param _listingHash The listingHash whose status is to be examined
    */
    function appWasMade(bytes32 _listingHash) view public returns (bool exists) {
        return listings[_listingHash].applicationExpiry > 0;
    }

    /**
    @dev                Returns true if apply was called for this listingHash and subjectHash
    @param _listingHash The listingHash whose status is to be examined
    */
    function subjectAppWasMade(bytes32 _listingHash, bytes32 _subjectHash) view public returns (bool exists) {
        return listings[_listingHash].subjects[_subjectHash].subjectExpiry > 0;
    }

    /**
    @dev                Determines the number of tokens awarded to the winning party in a challenge.
    @param _challengeID The challengeID to determine a reward for
    */
    function determineReward(uint _challengeID) public view returns (uint) {
        require(!challenges[_challengeID].resolved && voting.pollEnded(_challengeID));

        // Edge case, nobody voted, give all tokens to the challenger.
        if (voting.getTotalNumberOfTokensForWinningOption(_challengeID) == 0) {
            return 2 * challenges[_challengeID].stake;
        }

        return (2 * challenges[_challengeID].stake) - challenges[_challengeID].rewardPool;
    }

    /**
    @dev                    Getter for Listing subejcts mappings
    @param _listingHash     The hash of the listing
    @param _subjectHash     The hash of the subject
    */
    function listingSubjects(bytes32 _listingHash, bytes32 _subjectHash) public view returns(uint, bool, uint) {
        return (
            listings[_listingHash].subjects[_subjectHash].subjectExpiry,
            listings[_listingHash].subjects[_subjectHash].subjectWhitelisted,
            listings[_listingHash].subjects[_subjectHash].subjectUnstakedDeposit
        );
    }

    //
    // PRIVATE FUNCTIONS
    //
    /**
    @dev                Determines the winner in a challenge. Rewards the winner tokens and
                        either whitelists or de-whitelists the listingHash.
    @param _listingHash A listingHash with a challenge that is to be resolved
    */
    function resolveChallenge(bytes32 _listingHash) private {
        uint challengeID = listings[_listingHash].challengeID;
        bool challengeSubject = challenges[challengeID].isSubject;
        bytes32 subjectHash = challenges[challengeID].subject;

        // Calculates the winner's reward,
        // which is: (winner's full stake) + (dispensationPct * loser's stake)
        uint reward = determineReward(challengeID);

        // Sets flag on challenge being processed
        challenges[challengeID].resolved = true;

        // Stores the total tokens used for voting by the winning side for reward purposes
        challenges[challengeID].totalTokens =
            voting.getTotalNumberOfTokensForWinningOption(challengeID);

        // Case: challenge failed
        if (voting.isPassed(challengeID)) {

            // TODO: Unlock stake so that it can be retrieved by the applicant
            listings[_listingHash].unstakedDeposit += reward;

            if (challengeSubject) {
                // TODO: Unlock stake so that it can be retrieved by the applicant
                listings[_listingHash].subjects[subjectHash].subjectUnstakedDeposit += reward;

                // TODO: Whitelist subject
                whitelistSubject(_listingHash, subjectHash);
            }

            // TODO: Whitelist application
            whitelistApplication(_listingHash);
            
            _ChallengeFailed(_listingHash, challengeID, challenges[challengeID].rewardPool, challenges[challengeID].totalTokens);
        }

        // Case: challenge succeeded or nobody voted
        else {

            if (challengeSubject) {
                // Remove subject
                resetSubjectListing(_listingHash, subjectHash);

            } else {
                // Remove from the list
                resetListing(_listingHash);
            }
            // Transfer the reward to the challenger
            require(token.transfer(challenges[challengeID].challenger, reward), "Couldn't transfer the reward token to the challenger");

            emit _ChallengeSucceeded(_listingHash, challengeID, challenges[challengeID].rewardPool, challenges[challengeID].totalTokens);
        }

    }

    function whitelistSubject(bytes32 _listingHash, bytes32 _subjectHash) private {
        listings[_listingHash].subjects[_subjectHash].subjectWhitelisted = true;
    }

    /**
    @dev                Called by updateStatus() if the applicationExpiry date passed without a
                        challenge being made. Called by resolveChallenge() if an
                        application/listing beat a challenge.
    @param _listingHash The listingHash of an application/listingHash to be whitelisted
    */
    function whitelistApplication(bytes32 _listingHash) private {
        if (!listings[_listingHash].whitelisted) { 
            emit _ApplicationWhitelisted(_listingHash); 
            }
        listings[_listingHash].whitelisted = true;
    }

    /**
    @dev                Deletes a subjectHash from the whitelist and transfers tokens back to owner
    @param _listingHash The listing hash to delete
    @param _subjectHash The subject hash to delete
    */
    function resetSubjectListing(bytes32 _listingHash, bytes32 _subjectHash) private {
        Listing storage listing = listings[_listingHash];

        // Emit events before deleting listing to check whether is whitelisted
        if (listing.subjects[_subjectHash].subjectWhitelisted) {
            emit _ListingSubjectRemoved(_listingHash, _subjectHash);
        } else {
            emit _ApplicationSubjectRemoved(_listingHash, _subjectHash);
        }

        // Deleting subject to prevent reentry
        address owner = listing.owner;
        uint unstakedDeposit = listing.subjects[_subjectHash].subjectUnstakedDeposit;
        delete listing.subjects[_subjectHash];

        // Transfers any remaining balance back to the owner
        if (unstakedDeposit > 0){
            require(token.transfer(owner, unstakedDeposit), "Couldn't transfer the token");
        }
    }

    /**
    @dev                Deletes a listingHash from the whitelist and transfers tokens back to owner
    @param _listingHash The listing hash to delete
    */
    function resetListing(bytes32 _listingHash) private {
        Listing storage listing = listings[_listingHash];

        // Emit events before deleting listing to check whether is whitelisted
        if (listing.whitelisted) {
            emit _ListingRemoved(_listingHash);
        } else {
            emit _ApplicationRemoved(_listingHash);
        }

        // Deleting listing to prevent reentry
        address owner = listing.owner;
        uint unstakedDeposit = listing.unstakedDeposit;
        delete listings[_listingHash];

        // Transfers any remaining balance back to the owner
        if (unstakedDeposit > 0){
            require(token.transfer(owner, unstakedDeposit), "Couldn't transfer the token");
        }
    }
 
}