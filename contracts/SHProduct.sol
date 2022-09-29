// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/ISHProduct.sol";
import "./interfaces/ISHNFT.sol";
import "./interfaces/IUSDC.sol";
import "./SHNFT.sol";

contract SHProduct is ISHProduct, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    string public name;
    string public underlying;

    address public constant USDC = 0x818ec0A7Fe18Ff94269904fCED6AE3DaE6d6dC0b;
    /// @notice role in charge of status transition automation: Gelato Ops
    address public constant ops = 0x6c3224f9b3feE000A444681d5D45e4532D5BA531;
    address public qredoDeribit;

    uint256 public tokenId;
    uint256 public maxCapacity;
    uint256 public currentCapacity;

    Status public status;
    IssuanceCycle public issuanceCycle;

    address public shNFT;

    mapping(address => uint256) public balances;

    event ShNFTCreated(
        address indexed _product,
        address indexed _shNFT
    );

    event Deposit(
        address _user,
        uint256 _amount,
        uint256 _tokenId,
        uint256 _supply
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
    }

    function fundLock() external onlyOps {
        status = Status.Locked;
    }

    function issuance() external onlyOps {
        status = Status.Issued;
    }

    function mature() external onlyOps {
        status = Status.Mature;
    }

    function setTokenId(uint256 _tokenId) external {
        tokenId = _tokenId;
    }

    function setIssuanceCycle(
        IssuanceCycle calldata _issuanceCycle
    ) external onlyOwner {
        issuanceCycle = _issuanceCycle;
    }
    
    /**
     * @notice Deposits the USDC into the structured product and mint ERC1155 NFT
     * @param _amount is the amount of USDC to deposit
     */
    function deposit(uint256 _amount) external nonReentrant onlyAccepted {
        require(_amount > 0, "Amount must be greater than zero");
        uint256 decimals = IUSDC(USDC).decimals();
        uint256 supply = _amount % (1000 * 10 ** decimals);
        require(supply == 0, "Amount must be whole-number thousands");

        currentCapacity += _amount;
        require(maxCapacity >= currentCapacity, "Product is full");

        IERC20(USDC).safeTransferFrom(msg.sender, address(this), _amount);

        ISHNFT(shNFT).mint(msg.sender, tokenId, supply, "");
        balances[msg.sender] = _amount;
        
        emit Deposit(msg.sender, _amount, tokenId, supply);
    }
}
