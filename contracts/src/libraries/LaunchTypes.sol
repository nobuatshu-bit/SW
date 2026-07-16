// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

library LaunchTypes {
    enum ProjectState {
        Pending,
        Live,
        Graduated,
        Cancelled
    }

    struct CreateLaunchParams {
        string tokenName;
        string tokenSymbol;
        uint256 saleTokenAllocation;
        uint256 tokenPrice;
        uint256 softCap;
        uint256 maxRaise;
        uint64 startTime;
        uint64 endTime;
    }

    struct LaunchInit {
        address factory;
        address creator;
        address token;
        address feeRecipient;
        uint16 protocolFeeBps;
        uint256 saleTokenAllocation;
        uint256 tokenPrice;
        uint256 softCap;
        uint256 maxRaise;
        uint64 startTime;
        uint64 endTime;
    }

    struct LaunchInfo {
        address creator;
        address token;
        uint256 saleTokenAllocation;
        uint256 tokenPrice;
        uint256 softCap;
        uint256 maxRaise;
        uint64 startTime;
        uint64 endTime;
        uint16 protocolFeeBps;
    }

    // ── LaunchFactory types ───────────────────────────────────────────────────

    /// @dev Input struct accepted by LaunchFactory.createLaunch.
    ///      Separated from CreateLaunchParams to keep LaunchFactory decoupled
    ///      from the SherwoodFactory parameter surface.
    struct LaunchParams {
        /// Human-readable project name, max 64 bytes.
        string name;
        /// Short project description or tagline, max 256 bytes.
        string description;
        /// Metadata URI (IPFS CID or HTTPS URL) for off-chain project details.
        string metadataURI;
        /// ERC-20 token address participants will receive.
        address token;
        /// Fixed price per token unit in native currency (WAD-denominated, 1e18 = 1 ETH).
        uint256 tokenPrice;
        /// Total token amount allocated to this sale.
        uint256 tokenAllocation;
        /// Minimum native-currency raise for the launch to graduate.
        uint256 softCap;
        /// Maximum native-currency raise cap. Must be >= softCap.
        uint256 hardCap;
        /// Unix timestamp (seconds) when the sale window opens.
        uint64 startTime;
        /// Unix timestamp (seconds) when the sale window closes.
        uint64 endTime;
    }

    /// @dev Immutable snapshot stored in the factory registry when a launch is created.
    ///      Read by the backend indexer via getLaunchRecord().
    struct LaunchRecord {
        /// Address of the deployed Launch clone.
        address launch;
        /// Creator who submitted the launch.
        address creator;
        /// ERC-20 token address for this launch.
        address token;
        /// Protocol fee in basis points captured at creation time.
        uint16 protocolFeeBps;
        /// Fixed token price in native currency (WAD).
        uint256 tokenPrice;
        /// Total token allocation for the sale.
        uint256 tokenAllocation;
        /// Minimum raise required for graduation.
        uint256 softCap;
        /// Maximum raise cap.
        uint256 hardCap;
        /// Sale open timestamp.
        uint64 startTime;
        /// Sale close timestamp.
        uint64 endTime;
        /// Block timestamp at which the record was written.
        uint64 createdAt;
    }
}
