// Package service defines application service interfaces for the SHERWOOD API.
// Interfaces live here; implementations will be created in Sprint 3.
// Handlers depend on these interfaces, never on concrete types, keeping the
// delivery layer independent of database and blockchain libraries.
package service

import (
	"context"

	"github.com/sherwood-labs/sherwood/backend/api/internal/domain/launch"
)

// CreateLaunchInput carries validated parameters for creating a launch draft.
type CreateLaunchInput struct {
	CreatorID           string
	Name                string
	Tagline             string
	Description         string
	LogoURL             *string
	BannerURL           *string
	WebsiteURL          *string
	SocialLinks         map[string]string
	TokenName           string
	TokenSymbol         string
	TokenPrice          string
	SaleTokenAllocation string
	SoftCap             string
	MaxRaise            string
	StartTime           int64
	EndTime             int64
}

// UpdateLaunchInput carries the off-chain fields that may be changed after creation.
// A nil pointer means "leave unchanged".
type UpdateLaunchInput struct {
	Name        *string
	Tagline     *string
	Description *string
	LogoURL     *string
	BannerURL   *string
	WebsiteURL  *string
	SocialLinks map[string]string
}

// LaunchListInput carries validated pagination and filter parameters.
type LaunchListInput struct {
	Status  *launch.ProjectState
	ChainID *int64
	Limit   int
	Offset  int
}

// LaunchListResult is the paginated response returned by LaunchService.List.
type LaunchListResult struct {
	Launches []*launch.Launch
	Total    int
}

// LaunchService defines all business operations on the Launch aggregate.
// Every method validates its input, enforces business rules, and delegates
// persistence to the domain repository. No SQL lives here.
type LaunchService interface {
	// Create validates input and persists a new launch draft owned by creatorID.
	// Enforces the maximum-active-launches-per-creator limit.
	Create(ctx context.Context, input CreateLaunchInput) (*launch.Launch, error)

	// GetByID returns a single launch. Returns apierr.NotFound if absent.
	GetByID(ctx context.Context, id string) (*launch.Launch, error)

	// List returns a filtered, paginated list of launches.
	List(ctx context.Context, input LaunchListInput) (*LaunchListResult, error)

	// Update applies off-chain metadata changes to a draft launch.
	// Returns apierr.Forbidden if callerID does not own the launch.
	// Returns apierr.NotEditable if the launch status does not allow edits.
	Update(ctx context.Context, id string, callerID string, input UpdateLaunchInput) (*launch.Launch, error)

	// ListByCreator returns all launches belonging to a creator, newest first.
	ListByCreator(ctx context.Context, creatorID string, limit, offset int) (*LaunchListResult, error)
}
