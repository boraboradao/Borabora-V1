// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../library/MerkleProof.sol";
import "../interface/ITokenInterface.sol";

contract BEP20Basic is ERC20, MerkleProof {

    address private owner;

    mapping(address => bool) private executor;

    bytes32 private merkleInviteWhiteRoot;

    bytes32 private merkleBonusRoot;

    mapping(address => bool) public claimBonusUsers;

    mapping(address => bool) public whiteTransAddr;

    bool public _open_receive;

    bool public _open_claim_bonus;

    constructor (
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_,
        address[] memory whiteAddress,
        address[] memory executor_
    ) ERC20(name_,symbol_) {
        owner = msg.sender;
        setExecutor(executor_);
        setWhiteAddress(whiteAddress);
        _mint(owner, totalSupply_);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can execute");
        _;
    }

    modifier onlyExecutor() {
        require(executor[msg.sender] || msg.sender == owner, "Only executor");
        _;
    }

    function burn(uint256 amount) public returns (bool) {
        _burn(msg.sender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        require(whiteTransAddr[msg.sender], "The receiving address can only be the contract address");
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        require(whiteTransAddr[msg.sender], "The receiving address can only be the contract address");
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function transferOwner(address owner_) external onlyOwner returns (bool){
        require(owner_ != address(0x0), "owner address 0x0");
        uint256 _balance = balanceOf(msg.sender);
        if (_balance > 0) {
            _transfer(msg.sender, owner_, _balance);
        }
        owner = owner_;
        return true;
    }

    function setWhiteInviteMerkleRoot(bytes32 _rootHash) external onlyExecutor returns (bool) {
        merkleInviteWhiteRoot = _rootHash;
        return true;
    }
    
    function setBonusMerkleRoot(bytes32 _rootHash) external onlyExecutor returns (bool) {
        merkleBonusRoot = _rootHash;
        return true;
    }

    function setOpenReceive (bool opened) external onlyExecutor returns (bool) {
        _open_receive = opened;
        return true;
    }

    function setOpenBonus (bool opened) external onlyExecutor returns (bool) {
        _open_claim_bonus = opened;
        return true;
    }

    function whiteListBeInvitedClaim(uint256 amount,bytes32[] memory _merkleProof) internal view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender,amount));
        require(verify(_merkleProof,merkleInviteWhiteRoot,leaf), "Verification Failed");
        return true;
    }

    function whiteListInvitedClaim(uint256 invitedPeople,uint256 invitedTotal,uint256 amount,bytes32[] memory _merkleProof) internal view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(invitedPeople,invitedTotal,msg.sender,amount));
        require(verify(_merkleProof,merkleInviteWhiteRoot,leaf), "Verification Failed");
        return true;
    }

    function bonusListClaim(uint256 amount,uint256 burnAmount,bytes32[] memory _merkleProof) internal view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender,amount,burnAmount));
        require(verify(_merkleProof,merkleBonusRoot,leaf), "Bonus Verification Failed");
        return true;
    }

    function claimBonus(uint256 amount,uint256 burnAmount,bytes32[] memory _merkleProof,address tokenAddress) public {
        require(_open_claim_bonus, "Claim has not yet started");
        require(!claimBonusUsers[msg.sender], "The bonus has been claimed");
        require(bonusListClaim(amount,burnAmount,_merkleProof), "Bonus Verification Failed");
        claimBonusUsers[msg.sender] = true;
        _claimBonus(amount,burnAmount,tokenAddress);
    }

    function _claimBonus(uint256 amount,uint256 burnAmount, address tokenAddress) private {
        IToken token = IToken(tokenAddress);
        token.transfer(msg.sender,amount);
        _burn(msg.sender, burnAmount);
        emit ClaimBonused(msg.sender,amount,burnAmount);
    }

    function withdraw(address tokenAddress) external onlyOwner {
        IToken token = IToken(tokenAddress);
        uint256 _balance = token.balanceOf(address(this));
        token.transfer(msg.sender, _balance);
        emit Withdrawed(msg.sender, _balance);
    }

    function setExecutor (address[] memory executor_) public onlyOwner returns (bool) {
        for (uint i = 0; i < executor_.length;i++) {
            executor[executor_[i]] = true;
        }
        return true;
    }

    function revokeExecutor (address[] memory oldExecutor_) public onlyOwner returns (bool) {
        for (uint i = 0; i < oldExecutor_.length;i++) {
            executor[oldExecutor_[i]] = false;
        }
        return true;
    }

    function setWhiteAddress (address[] memory contractAddress) public onlyExecutor returns (bool) {
        for (uint i = 0;i < contractAddress.length;i++) {
            if (!whiteTransAddr[contractAddress[i]]) {
                whiteTransAddr[contractAddress[i]] = true;
            }
        }
        return true;
    }

    event Claimed(address recipient,uint256 amount,address tokenAddress);

    event ClaimBonused(address recipient,uint256 amount,uint256 burnAmount);

    event Minted(address recipient,uint256 amount,address tokenAddress);

    event Withdrawed(address recipient,uint256 amount);
}
