package service

import "context"

// PortfolioPosition is the computed state of one user-launch relationship.
type PortfolioPosition struct {
	LaunchID         string
	LaunchName       string
	LaunchLogoURL    *string
	ContractAddress  *string
	Status           string
	TokenSymbol      string
	TokenAddress     *string
	TokensPurchased  string // decimal string
	TokensClaimed    string // decimal string
	TokensClaimable  string // decimal string (= Purchased - Claimed)
	TotalContributed string // WAD decimal string
	Refundable       string // WAD decimal string
}

// Portfolio aggregates all positions for a single wallet address.
type Portfolio struct {
	UserID                  string
	WalletAddress           string
	Positions               []*PortfolioPosition
	TotalContributed        string
	TotalClaimablePositions int
	TotalRefundablePositions int
}

// PortfolioService computes a user's portfolio by aggregating transaction
// records across all launches they have participated in.
type PortfolioService interface {
	// GetByWalletAddress returns the full portfolio for the given address.
	GetByWalletAddress(ctx context.Context, address string, chainID int64) (*Portfolio, error)
}
