// Package transaction defines the Transaction domain model and repository.
// Transactions are immutable indexed records of on-chain events.
package transaction

import (
	"context"
	"time"
)

// TransactionType classifies each on-chain action.
type TransactionType string

const (
	TypeBuy    TransactionType = "buy"
	TypeSell   TransactionType = "sell"
	TypeCreate TransactionType = "create"
	TypeClaim  TransactionType = "claim"
	TypeRefund TransactionType = "refund"
)

// Transaction is an immutable record of a single indexed on-chain event.
type Transaction struct {
	ID             string
	LaunchID       string
	UserID         *string // nil for wallets with no registered account
	WalletAddress  string
	ChainID        int64
	TxHash         string
	BlockNumber    int64
	BlockTimestamp int64
	Type           TransactionType
	NativeAmount   *string // WAD decimal string, nil for non-value txs
	TokenAmount    *string // decimal string, nil for non-token txs
	IndexedAt      time.Time
}

// ListFilter carries optional filter parameters for listing transactions.
type ListFilter struct {
	LaunchID      *string
	WalletAddress *string
	Type          *TransactionType
	Limit         int
	Offset        int
}

// Repository defines all persistence operations for Transaction records.
// Transactions are never updated or deleted — only created and read.
type Repository interface {
	// GetByID returns the transaction with the given internal UUID.
	GetByID(ctx context.Context, id string) (*Transaction, error)

	// GetByTxHash returns the transaction with the given on-chain hash.
	GetByTxHash(ctx context.Context, txHash string, chainID int64) (*Transaction, error)

	// List returns a filtered, paginated list of transactions and total count.
	List(ctx context.Context, filter ListFilter) ([]*Transaction, int, error)

	// Create persists a new indexed transaction record.
	Create(ctx context.Context, t *Transaction) (*Transaction, error)

	// ExistsByTxHash reports whether a transaction with the given hash and
	// chain has already been indexed. Used for idempotency by the indexer.
	ExistsByTxHash(ctx context.Context, txHash string, chainID int64) (bool, error)
}
