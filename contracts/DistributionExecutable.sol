//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { AxelarExecutable } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/executables/AxelarExecutable.sol';
import { IAxelarGateway } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol';
import { IERC20 } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IERC20.sol';
import { IAxelarGasService } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol';
import "./interfaces/clearpool/IPoolMaster.sol";

contract DistributionExecutable is AxelarExecutable {
    IAxelarGasService public immutable gasReceiver;

    constructor(address gateway_, address gasReceiver_) AxelarExecutable(gateway_) {
        gasReceiver = IAxelarGasService(gasReceiver_);
    }

    function sendAssetToPools(
        string memory destinationChain,
        string memory destinationAddress,
        address[] calldata pools,
        uint256[] calldata percents,
        string memory symbol,
        uint256 amount
    ) external payable {
        require(pools.length == percents.length, "Pools array should have same length as percents");
        address tokenAddress = gateway.tokenAddresses(symbol);
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        IERC20(tokenAddress).approve(address(gateway), amount);
        bytes memory payload = abi.encode(pools, percents);
        if (msg.value > 0) {
            gasReceiver.payNativeGasForContractCallWithToken{ value: msg.value }(
                address(this),
                destinationChain,
                destinationAddress,
                payload,
                symbol,
                amount,
                msg.sender
            );
        }
        gateway.callContractWithToken(destinationChain, destinationAddress, payload, symbol, amount);
    }

    function _executeWithToken(
        string calldata,
        string calldata,
        bytes calldata payload,
        string calldata tokenSymbol,
        uint256 amount
    ) internal override {
        address[] memory pools;
        uint256[] memory percents;

        (pools, percents) = abi.decode(payload, (address[], uint256[]));
        address tokenAddress = gateway.tokenAddresses(tokenSymbol);

        // swap from axlUSDC to USDC via any available dex(f.g. curve) on polygon
        for (uint256 i = 0; i < pools.length; i++) {
            uint256 lendAmount = amount * percents[i] / 100;
            IPoolMaster(pools[i]).provide(lendAmount);
        }
    }
}
