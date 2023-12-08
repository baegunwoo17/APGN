// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "hardhat/console.sol";
import "./VAPGN.sol";
import "./AuroraPenguinToken.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
struct Item { // 안건
    uint256 id;
    string title;
    string content;
    VoteState state;
    string[] options;
    uint256 createdTimestamp;
    uint256 daysAfter; // day
    uint256[] votes;
    address writer;
    mapping(address => uint256[]) receipts;
}
struct ShortItem {
    uint256 id;
    string title;
    VoteState state;
    uint256 createdTimestamp;
    uint256 daysAfter;
    bool isParticipated;
}
struct DetailItem {
    uint256 id;
    string title;
    string content;
    VoteState state;
    uint256 createdTimestamp;
    uint256 daysAfter;
    address writer;
    OptionData options;
    VoteData votes;
    VoteData myVotes;
}
struct OptionData {
    string[] options;
}
struct VoteData {
    uint256[] votes;
}
enum VoteState {
    OnGoing,
    Pause,
    Finished
}
contract Vote {
    address private owner;
    VAPGN private _vApgn;
    AuroraPenguinToken private _apgn;
    constructor(address apgnContractAddress, address vApgnContractAddress) {
        owner = msg.sender;
        _apgn = AuroraPenguinToken(apgnContractAddress);
        _vApgn = VAPGN(vApgnContractAddress);
    }
    Item[] public items;
    uint registerFee = 2000 * 10 ** 18;
    // 투표를 제안하다
    function propose(string memory title, string memory content, uint256 daysAfter, string[] memory options) public {
        require(_apgn.allowance(msg.sender, address(this)) >= registerFee, "Not Enough Allowance!");
        require(bytes(title).length != 0, "title is empty.");
        require(bytes(content).length != 0, "content is empty.");
        require(daysAfter > 0, "daysAfter is bigger than Zero");
        require(options.length > 0, "options is empty");
        uint256 itemsLength = items.length;
        Item storage newItem = items.push();
        newItem.id = itemsLength;
        newItem.title = title;
        newItem.content = content;
        newItem.state = VoteState.OnGoing;
        newItem.options = options;
        newItem.createdTimestamp = block.timestamp;
        newItem.daysAfter = daysAfter;
        newItem.votes = new uint256[](options.length);
        newItem.writer = msg.sender;
        _apgn.transferFrom(msg.sender, _apgn.owner(), registerFee);
    }
    function totalProposes() public view returns  (uint256) {
        return items.length;
    }
    function getProposes() external view returns (ShortItem[] memory) {
        ShortItem[] memory shorts = new ShortItem[](items.length);
        for(uint256 i = 0; i < items.length; i++) {
            bool isParticipated = false;
            if (items[i].receipts[msg.sender].length > 0) {
                isParticipated = true;
            }
            shorts[i] = ShortItem(items[i].id, items[i].title, items[i].state, items[i].createdTimestamp, items[i].daysAfter, isParticipated);
        }
        return shorts;
    }
    function getPropose(uint itemId) public view returns (DetailItem memory) {
        Item storage item = items[itemId];
        require(item.id == itemId, "Not Found Proposal!");
        OptionData memory options = OptionData(item.options);
        VoteData memory votes = VoteData(item.votes);
        VoteData memory myVotes;
        if (item.receipts[msg.sender].length <= 0) {
            myVotes = VoteData(new uint256[](item.options.length));
        } else {
            myVotes = VoteData(item.receipts[msg.sender]);
        }
        return DetailItem(item.id, item.title, item.content, item.state, item.createdTimestamp, item.daysAfter, item.writer, options, votes, myVotes);
    }
    function voteItem(uint256 itemId, uint optionId, uint256 amount) public {
        require(amount > 0, "Input vAPGN");
        require(_vApgn.allowance(msg.sender, address(this)) >= amount, "Not Enough Allowance!");
        Item storage item = items[itemId];
        require(item.id == itemId, "Not Found Proposal!");
        require(block.timestamp < item.createdTimestamp + (86400 * item.daysAfter), "Finish Proposal!");
        item.votes[optionId] += amount;
        if (item.receipts[msg.sender].length <= 0) {
            item.receipts[msg.sender] = new uint256[](item.options.length);
        }
        item.receipts[msg.sender][optionId] += amount;
        address vTokenOwner = _vApgn.owner();
        _vApgn.transferFrom(msg.sender, vTokenOwner, amount);
        _vApgn.burnAfterVote(vTokenOwner, amount);
    }
}
