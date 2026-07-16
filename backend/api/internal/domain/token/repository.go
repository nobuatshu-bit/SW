// Package token defines the Token domain model and repository interface.
// A token is the ERC-20 contract deployed by SherwoodFactory for a launch.
package token

import (
	"context"
	"time"
)

// Token represents an ERC-20 contract deployed by SherwoodFactory.
type Token struct {
	ID             string
	LaunchID       string
	Address        string // EIP-55 checksummed contract address
	ChainID        int64
	Name           string
	Symbol         string
	Decimals       int   // always 18 for SHERWOOD tokens
	TotalSupply    string // decimal string (uint256)
	FactoryAddress string // address that deployed this token
	DeployedAt     time.Time
}

// Repository defines all persistence operations for Token aggregates.
type Repository interface {
	// GetByID returns the token with the given internal UUID.
	GetByID(ctx context.Context, id string) (*Token, error)

	// GetByAddress returns the token with the given on-chain contract address.
	GetByAddress(ctx context.Context, address string, chainID int64) (*Token, error)

	// GetByLaunchID returns the token associated with a launch.
	// Returns apierr.NotFound if no token has been deployed yet.
	GetByLaunchID(ctx context.Context, launchID string) (*Token, error)

	// Create persists a newly indexed token record.
	Create(ctx context.Context, t *Token) (*Token, error)
}
