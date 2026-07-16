package service

import (
	"context"

	"github.com/sherwood-labs/sherwood/backend/api/internal/domain/transaction"
)

// IndexTransactionInput carries the data extracted from an on-chain event log
// that the indexer passes to TransactionService.
type IndexTransactionInput struct {
	LaunchID       string
	WalletAddress  string
	ChainID        int64
	TxHash         string
	BlockNumber    int64
	BlockTimestamp int64
	Type           transaction.TransactionType
	NativeAmount   *string // nil for non-value events
	TokenAmount    *string // nil for non-token events
}

// TransactionListInput carries validated pagination and filter parameters.
type TransactionListInput struct {
	LaunchID      *string
	WalletAddress *string
	Type          *transaction.TransactionType
	Limit         int
	Offset        int
}

// TransactionListResult is the paginated response from TransactionService.List.
type TransactionListResult struct {
	Transactions []*transaction.Transaction
	Total        int
}

// TransactionService handles indexing of on-chain events and querying of
// transaction history. All writes are idempotent to support indexer restarts.
type TransactionService interface {
	// GetByID returns a single transaction by internal UUID.
	GetByID(ctx context.Context, id string) (*transaction.Transaction, error)

	// GetByTxHash returns a single transaction by on-chain hash and chain ID.
	GetByTxHash(ctx context.Context, txHash string, chainID int64) (*transaction.Transaction, error)

	// List returns a filtered, paginated list of transactions.
	List(ctx context.Context, input TransactionListInput) (*TransactionListResult, error)

	// Index persists an on-chain event as a transaction record.
	// Idempotent: if txHash + chainID already exists, the existing record is returned.
	Index(ctx context.Context, input IndexTransactionInput) (*transaction.Transaction, error)
}
