package service

import (
	"context"

	"github.com/sherwood-labs/sherwood/backend/api/internal/domain/token"
)

// IndexTokenInput carries the data emitted by a ProjectCreated event that the
// indexer passes to TokenService when recording a new on-chain deployment.
type IndexTokenInput struct {
	LaunchID       string
	Address        string
	ChainID        int64
	Name           string
	Symbol         string
	TotalSupply    string // decimal string
	FactoryAddress string
	DeployedAt     string // ISO-8601
}

// TokenService handles registration and lookup of deployed ERC-20 tokens.
type TokenService interface {
	// GetByLaunchID returns the token associated with a launch.
	// Returns apierr.NotFound (TOKEN_NOT_DEPLOYED) if no token has been indexed yet.
	GetByLaunchID(ctx context.Context, launchID string) (*token.Token, error)

	// GetByAddress returns the token for a given on-chain address and chain.
	GetByAddress(ctx context.Context, address string, chainID int64) (*token.Token, error)

	// Index persists a newly deployed token record. Idempotent — calling it
	// twice for the same address and chain returns the existing record.
	Index(ctx context.Context, input IndexTokenInput) (*token.Token, error)
}
