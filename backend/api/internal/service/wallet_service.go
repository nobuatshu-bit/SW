package service

import (
	"context"

	"github.com/sherwood-labs/sherwood/backend/api/internal/domain/wallet"
)

// ConnectWalletInput carries the parameters submitted when a user connects a wallet.
type ConnectWalletInput struct {
	UserID     string
	Address    string
	ChainID    int64
	WalletType wallet.WalletType
}

// VerifySIWEInput carries a Sign-In With Ethereum (SIWE) challenge response.
type VerifySIWEInput struct {
	Message   string // EIP-4361 plaintext message
	Signature string // 0x-prefixed 65-byte hex
	Address   string // signer address for cross-check
}

// SIWESession is the result of a successful SIWE verification.
type SIWESession struct {
	Token  string       // signed JWT to return to the client
	Wallet *wallet.Wallet
}

// WalletService handles wallet connection, SIWE authentication, and session
// management. JWT signing is performed here so the delivery layer only
// exchanges opaque session tokens.
type WalletService interface {
	// GetNonce generates and persists a one-time SIWE nonce for the given address.
	GetNonce(ctx context.Context, address string) (nonce string, issuedAt string, err error)

	// VerifySIWE validates a SIWE signature, creates or loads the user account,
	// upserts the wallet record, and issues a signed JWT.
	VerifySIWE(ctx context.Context, input VerifySIWEInput) (*SIWESession, error)

	// Connect links a wallet address to an existing user account.
	Connect(ctx context.Context, input ConnectWalletInput) (*wallet.Wallet, error)

	// GetByAddress returns the wallet record for a given address and chain.
	GetByAddress(ctx context.Context, address string, chainID int64) (*wallet.Wallet, error)

	// ListByUser returns all wallets belonging to a user.
	ListByUser(ctx context.Context, userID string) ([]*wallet.Wallet, error)

	// SetPrimary sets the given wallet as the user's primary wallet.
	SetPrimary(ctx context.Context, walletID string, userID string) error
}
