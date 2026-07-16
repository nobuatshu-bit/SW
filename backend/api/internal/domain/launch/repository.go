// Package launch defines the Launch domain model, state machine, and
// repository interface. Launch is the central aggregate of the SHERWOOD protocol.
package launch

import (
	"context"
	"time"
)

// ProjectState mirrors the on-chain enum in LaunchTypes.sol and the
// additional off-chain-only states managed by the backend.
type ProjectState string

const (
	StateDraft        ProjectState = "draft"
	StatePendingReview ProjectState = "pending_review"
	StateUpcoming     ProjectState = "upcoming"
	StateLive         ProjectState = "live"
	StateCompleted    ProjectState = "completed"
	StateCancelled    ProjectState = "cancelled"
)

// Launch is the central aggregate model for a SHERWOOD token launch.
type Launch struct {
	ID              string
	CreatorID       string
	TokenID         *string  // nil until contract is deployed
	ContractAddress *string  // nil until contract is deployed
	ChainID         int64
	Status          ProjectState

	// Off-chain metadata
	Name        string
	Tagline     string
	Description string
	LogoURL     *string
	BannerURL   *string
	WebsiteURL  *string
	SocialLinks map[string]string

	// On-chain parameters (stored as strings to preserve uint256 precision)
	TokenName           string
	TokenSymbol         string
	TokenPrice          *string // WAD decimal string, nil until deployed
	SaleTokenAllocation *string
	SoftCap             *string
	MaxRaise            *string
	TotalRaised         *string
	ProtocolFeeBps      *int
	StartTime           *int64 // Unix seconds
	EndTime             *int64 // Unix seconds

	CreatedAt time.Time
	UpdatedAt time.Time
}

// ListFilter carries optional filter parameters for listing launches.
type ListFilter struct {
	Status  *ProjectState
	ChainID *int64
	Limit   int
	Offset  int
}

// Repository defines all persistence operations for Launch aggregates.
type Repository interface {
	// GetByID returns the launch with the given internal UUID.
	GetByID(ctx context.Context, id string) (*Launch, error)

	// GetByContractAddress returns the launch whose on-chain contract address matches.
	GetByContractAddress(ctx context.Context, address string, chainID int64) (*Launch, error)

	// List returns a filtered, paginated slice of launches and the total count.
	List(ctx context.Context, filter ListFilter) ([]*Launch, int, error)

	// ListByCreator returns all launches owned by a creator ID, newest first.
	ListByCreator(ctx context.Context, creatorID string, limit, offset int) ([]*Launch, int, error)

	// Create persists a new launch draft and returns the created model.
	Create(ctx context.Context, l *Launch) (*Launch, error)

	// Update applies a full model update (used after status transitions and
	// off-chain metadata edits). Callers must fetch before updating.
	Update(ctx context.Context, l *Launch) (*Launch, error)

	// UpdateStatus transitions the launch to the given state.
	// Implementations must enforce valid state transitions.
	UpdateStatus(ctx context.Context, id string, status ProjectState) error

	// UpdateOnChainData persists contract address and on-chain sale parameters
	// after the ProjectCreated event is indexed.
	UpdateOnChainData(ctx context.Context, id string, patch OnChainPatch) error

	// CountActiveByCreator returns how many non-cancelled, non-completed
	// launches the creator currently has.
	CountActiveByCreator(ctx context.Context, creatorID string) (int, error)
}

// OnChainPatch carries the fields written when indexing a ProjectCreated event.
type OnChainPatch struct {
	ContractAddress     string
	TokenID             string
	TokenPrice          string
	SaleTokenAllocation string
	SoftCap             string
	MaxRaise            string
	ProtocolFeeBps      int
	StartTime           int64
	EndTime             int64
}
