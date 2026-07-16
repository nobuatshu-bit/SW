// Package wallet defines the Wallet domain model and its repository interface.
// A wallet represents a connected EVM address linked to a user account.
package wallet

import (
	"context"
	"time"
)

// WalletType mirrors the TypeScript WalletType enum and the database enum.
type WalletType string

const (
	WalletTypeInjected     WalletType = "injected"
	WalletTypeWalletConnect WalletType = "wallet_connect"
	WalletTypeCoinbase     WalletType = "coinbase"
)

// Wallet is the domain model for a connected EVM wallet.
type Wallet struct {
	ID          string
	UserID      string
	Address     string     // EIP-55 checksummed
	Chain       int64      // EVM chain ID
	WalletType  WalletType
	IsPrimary   bool
	ConnectedAt time.Time
	LastSeenAt  time.Time
}

// Repository defines all persistence operations for Wallet aggregates.
type Repository interface {
	// GetByID returns the wallet with the given internal UUID.
	GetByID(ctx context.Context, id string) (*Wallet, error)

	// GetByAddress returns the wallet for a given EIP-55 address and chain ID.
	GetByAddress(ctx context.Context, address string, chainID int64) (*Wallet, error)

	// ListByUserID returns all wallets belonging to a user, ordered by IsPrimary desc.
	ListByUserID(ctx context.Context, userID string) ([]*Wallet, error)

	// Create persists a new wallet and returns the created model.
	Create(ctx context.Context, w *Wallet) (*Wallet, error)

	// SetPrimary marks the given wallet as primary and clears the flag on all
	// other wallets belonging to the same user. Must execute atomically.
	SetPrimary(ctx context.Context, walletID string, userID string) error

	// UpdateLastSeen updates the LastSeenAt timestamp for the given wallet.
	UpdateLastSeen(ctx context.Context, id string) error
}
