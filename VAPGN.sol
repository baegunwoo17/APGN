// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";
contract VAPGN is ERC20, Ownable {
    using SafeMath for uint256;
    using SafeCast for uint256;
    mapping(address => bool) controllers;
    uint256 private _totalSupply;
    constructor() ERC20("vAPGN", "vAPGN") {}
    function mint(address to, uint256 amount) public {
        require(controllers[msg.sender], "Only controllers can mint");
        _totalSupply = _totalSupply.add(amount);
        _mint(to, amount);
    }
    function burnAfterVote(address toAddress, uint256 amount) public {
        _burn(toAddress, amount);
    }
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
    function addController(address controller) external onlyOwner {
        controllers[controller] = true;
    }
    function removeController(address controller) external onlyOwner {
        controllers[controller] = false;
    }
    function totalSupply() public override view returns (uint256) {
        return _totalSupply;
    }
}
