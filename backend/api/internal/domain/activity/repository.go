// Package activity defines the Activity read model and its repository interface.
// Activity is a denormalised view derived from Transaction records, designed
// for efficient rendering of the global and per-launch activity feeds.
// It is a read model only — never written to directly by application code.
package activity

import (
	"context"
	"time"
)

// Activity is a denormalised feed item derived from a Transaction.
type Activity struct {
	ID             string // same as Transaction.ID
	LaunchID       string
	LaunchName     string  // denormalised
	UserID         *string // nil for unregistered wallets
	ActorLabel     string  // display name or truncated address
	WalletAddress  string
	TransactionType string
	Summary        string // pre-formatted, e.g. "Bought 1,200 VRD for 0.05 ETH"
	TxHash         string
	BlockTimestamp int64
	IndexedAt      time.Time
}

// ListFilter carries optional filter parameters for the activity feed.
type ListFilter struct {
	LaunchID      *string
	WalletAddress *string
	Limit         int
	Offset        int
}

// Repository defines read operations for the Activity feed.
// The write path is handled by the transaction indexer, which derives
// activity rows from confirmed transactions.
type Repository interface {
	// List returns a filtered, paginated activity feed and the total count.
	List(ctx context.Context, filter ListFilter) ([]*Activity, int, error)

	// ListByLaunch is a convenience wrapper for List filtered to a single launch.
	ListByLaunch(ctx context.Context, launchID string, limit, offset int) ([]*Activity, int, error)

	// ListByWallet returns all activity for a given wallet address, newest first.
	ListByWallet(ctx context.Context, address string, limit, offset int) ([]*Activity, int, error)
}
