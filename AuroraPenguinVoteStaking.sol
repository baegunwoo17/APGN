// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "../AuroraPenguinToken.sol";
import "../VAPGN.sol";
import "../AuroraPenguinNFT.sol";

contract vStaking is Ownable, IERC721Receiver {

    uint256 public totalStaked;
  
    // struct to store a stake's token, owner, and earning values
    struct Stake {
        uint24 tokenId;
        uint48 timestamp;
        address owner;
    }

    event NFTStaked(address owner, uint256 tokenId, uint256 value);
    event NFTUnstaked(address owner, uint256 tokenId, uint256 value);
    event Claimed(address owner, uint256 amount, uint256 amount2);

    // reference to the Block NFT contract
    AuroraPenguinNFT nft;
    AuroraPenguinToken token;
    VAPGN vToken;

    // maps tokenId to stake
    mapping(uint256 => Stake) public vault; 
    mapping(uint256 => Stake) public vault2; 

    uint256 public reward = 10 ether;
    uint256 public voteReward = 100 ether;

    constructor(AuroraPenguinNFT _nft, AuroraPenguinToken _token, VAPGN _vToken) { 
        nft = _nft;
        token = _token;
        vToken = _vToken;
    }

    function setReward(uint256 _reward) public onlyOwner() {
        reward = _reward * 10 ** 18;
    }

    function setVoteReward(uint256 _voteReward) public onlyOwner() {
        voteReward = _voteReward * 10 ** 18;
    }

    function stake(uint256[] calldata tokenIds) external {
        uint256 tokenId;
        totalStaked += tokenIds.length;
        for (uint i = 0; i < tokenIds.length; i++) {
            tokenId = tokenIds[i];
            require(nft.ownerOf(tokenId) == msg.sender, "not your token");
            require(vault[tokenId].tokenId == 0, 'already staked');
            require(vault2[tokenId].tokenId == 0, 'already staked');

            nft.transferFrom(msg.sender, address(this), tokenId);
            emit NFTStaked(msg.sender, tokenId, block.timestamp);

            vault[tokenId] = Stake({
                owner: msg.sender,
                tokenId: uint24(tokenId),
                timestamp: uint48(block.timestamp)
            });

            vault2[tokenId] = Stake({
                owner: msg.sender,
                tokenId: uint24(tokenId),
                timestamp: uint48(block.timestamp)
            });
        }
    }

    function _unstakeMany(address account, uint256[] calldata tokenIds) internal {
        uint256 tokenId;
        totalStaked -= tokenIds.length;
        for (uint i = 0; i < tokenIds.length; i++) {
            tokenId = tokenIds[i];

            Stake memory staked = vault[tokenId];
            Stake memory staked2 = vault2[tokenId];
            require(staked.owner == msg.sender, "not an owner");
            require(staked2.owner == msg.sender, "not an owner");

            delete vault[tokenId];
            delete vault2[tokenId];
            
            emit NFTUnstaked(account, tokenId, block.timestamp);
            nft.transferFrom(address(this), account, tokenId);
        }
    }

    function claim(uint256[] calldata tokenIds) external {
        _claim(msg.sender, tokenIds, false);
    }

    function claimForAddress(address account, uint256[] calldata tokenIds) external {
        _claim(account, tokenIds, false);
    }

    function unstake(uint256[] calldata tokenIds) external {
        _claim(msg.sender, tokenIds, true);
    }

    function _claim(address account, uint256[] calldata tokenIds, bool _unstake) internal {
        uint256 tokenId;
        uint256 earned = 0;
        uint256 vEarned = 0;

        for (uint i = 0; i < tokenIds.length; i++) {
            tokenId = tokenIds[i];

            Stake memory staked = vault[tokenId];
            Stake memory staked2 = vault2[tokenId];

            require(staked.owner == account, "not an owner");
            require(staked2.owner == account, "not an owner");

            uint256 stakedAt = staked.timestamp;
            uint256 stakedAt2 = staked2.timestamp;

            require(block.timestamp - stakedAt > 3600, "You can claim after 1 hour after the last claim.");
            earned = reward * (block.timestamp - stakedAt) / 86400 ;
            vEarned = voteReward * (block.timestamp - stakedAt2) / 86400 ;

            vault[tokenId] = Stake({
                owner: account,
                tokenId: uint24(tokenId),
                timestamp: uint48(block.timestamp)
            });

            vault2[tokenId] = Stake({
                owner: account,
                tokenId: uint24(tokenId),
                timestamp: uint48(block.timestamp)
            });
        }

        if (earned > 0 && vEarned > 0) {
            token.mint(account, earned);
            vToken.mint(account, vEarned);
        }

        if (_unstake) {
            _unstakeMany(account, tokenIds);
        }
        emit Claimed(account, earned, vEarned);
    }

    function earningInfo(address account, uint256[] calldata tokenIds) external view returns (uint256[2] memory info) {
        uint256 tokenId;
        uint256 earned = 0;
        uint256 vEarned = 0;

        for (uint i = 0; i < tokenIds.length; i++) {
            tokenId = tokenIds[i];

            Stake memory staked = vault[tokenId];
            Stake memory staked2 = vault2[tokenId];

            require(staked.owner == account, "not an owner");
            require(staked2.owner == account, "not an owner");

            uint256 stakedAt = staked.timestamp;
            uint256 stakedAt2 = staked2.timestamp;

            earned = reward * (block.timestamp - stakedAt) / 86400;
            vEarned = voteReward * (block.timestamp - stakedAt2) / 86400;
        }

        if (earned > 0 && vEarned > 0) {
            return [earned, vEarned];
        }
    }

    // should never be used inside of transaction because of gas fee
    function balanceOf(address account) public view returns (uint256) {
        uint256 balance = 0;
        uint256 supply = nft.totalSupply();
        for(uint i = 0; i < supply; i++) {
            if (vault[i].owner == account) {
                balance += 1;
            }
        }
        return balance;
    }

    // should never be used inside of transaction because of gas fee
    function tokensOfOwner(address account) public view returns (uint256[] memory ownerTokens) {

        uint256 supply = nft.totalSupply();
        uint256[] memory tmp = new uint256[](supply);

        uint256 index = 0;
        for(uint tokenId = 0; tokenId < supply; tokenId++) {
            if (vault[tokenId].owner == account) {
                tmp[index] = vault[tokenId].tokenId;
                index +=1;
            }
        }

        uint256[] memory tokens = new uint256[](index);
        for(uint i = 0; i < index; i++) {
            tokens[i] = tmp[i];
        }

        return tokens;
    }

    function onERC721Received(address, address from, uint256, bytes calldata) external pure override returns (bytes4) {
        require(from == address(0x0), "Cannot send nfts to Vault directly");
        return IERC721Receiver.onERC721Received.selector;
    }
  
}
