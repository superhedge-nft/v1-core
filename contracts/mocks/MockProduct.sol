// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/ISHProduct.sol";
import "../interfaces/ISHNFT.sol";
import "../interfaces/IUSDC.sol";
import "../SHNFT.sol";
import "hardhat/console.sol";
contract MockProduct is ISHProduct, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    string public name;
    string public underlying;

    address public USDC;
    /// @notice role in charge of status transition automation: Gelato Ops
    address public ops;
    address public qredoDeribit;

    uint256 public maxCapacity;
    uint256 public currentTokenId;
    uint256 public currentCapacity;

    Status public status;
    IssuanceCycle public issuanceCycle;

    address public shNFT;

    mapping(address => uint256) public balances;

    event Deposit(
        address _from,
        uint256 _amount,
        uint256 _currentTokenId,
        uint256 _supply
    );

    event Withdraw(
        address _to,
        uint256 _amount,
        uint256 _currentTokenId
    );

    /**
     * @dev Throws if called by any account other than the keeper.
     */
    modifier onlyOps() {
        require(msg.sender == ops, "OpsReady: onlyOps");
        _;
    }

    modifier onlyAccepted() {
        require(status == Status.Accepted, "Not accepted status");
        _;
    }

    modifier notIssued() {
        require(status != Status.Issued, "Issued status");
        _;
    }

    constructor(
        string memory _name,
        string memory _underlying,
        address _qredo_deribit,
        address _shNFT,
        uint256 _maxCapacity,
        IssuanceCycle memory _issuanceCycle
    ) {
        name = _name;
        underlying = _underlying;

        qredoDeribit = _qredo_deribit;
        maxCapacity = _maxCapacity;

        shNFT = _shNFT;
        issuanceCycle = _issuanceCycle;
    }

    function fundAccept() external onlyOps {
        status = Status.Accepted;
        currentCapacity = 0;
    }

    function fundLock() external onlyOps {
        status = Status.Locked;
    }

    function issuance() external onlyOps {
        status = Status.Issued;
        issuanceCycle.issuanceDate = block.timestamp;
    }

    function mature() external onlyOps {
        status = Status.Mature;
        issuanceCycle.maturityDate = block.timestamp;
    }

    function setCurrentTokenId(uint256 _id) external {
        currentTokenId = _id;
    }

    function setIssuanceCycle(
        IssuanceCycle calldata _issuanceCycle
    ) external onlyOwner notIssued {
        issuanceCycle = _issuanceCycle;
    }
    
    /**
     * @dev Deposits the USDC into the structured product and mint ERC1155 NFT
     * @param _amount is the amount of USDC to deposit
     */
    function deposit(uint256 _amount) external nonReentrant onlyAccepted {
        require(_amount > 0, "Amount must be greater than zero");
        uint256 decimals = IUSDC(USDC).decimals();
        require((_amount % (1000 * 10 ** decimals)) == 0, "Amount must be whole-number thousands");

        uint256 supply = _amount / (1000 * 10 ** decimals);
        uint256 prevTokenId = currentTokenId - 1;
        uint256 prevBalance = ISHNFT(shNFT).balanceOf(msg.sender, prevTokenId);

        currentCapacity += _amount;
        require((maxCapacity * 10 ** decimals) >= currentCapacity, "Product is full");

        IERC20(USDC).safeTransferFrom(msg.sender, address(this), _amount);

        if (prevBalance > 0) {
            ISHNFT(shNFT).burn(msg.sender, prevTokenId, prevBalance);
            supply += prevBalance;
        }
        
        ISHNFT(shNFT).mint(msg.sender, currentTokenId, supply, issuanceCycle.uri);
        balances[msg.sender] += _amount;
        
        emit Deposit(msg.sender, _amount, currentTokenId, supply);
    }

    /**
     * @dev Withdraws the specific amount of USDC from the structured product
     * @param _amount is the amount of USDC to withdraw
     */
    function withdraw(uint256 _amount) external nonReentrant onlyAccepted {
        require(_amount > 0, "Amount must be greater than zero");
        uint256 decimals = IUSDC(USDC).decimals();
        uint256 supply = _amount % (1000 * 10 ** decimals);
        require(supply == 0, "Amount must be whole-number thousands");
        require(balances[msg.sender] >= _amount, "Exceeds current balance");

        ISHNFT(shNFT).burn(msg.sender, currentTokenId, supply);
        currentCapacity -= _amount;
        balances[msg.sender] -= _amount;

        emit Withdraw(msg.sender, _amount, currentTokenId);
    }

    function setMockOps(address _ops) external {
        ops = _ops;
    }

    function setMockUSDC(address _usdc) external {
        USDC = _usdc;
    }
}
