// Package user defines the User domain model and the repository interface
// that the Postgres implementation must satisfy. No SQL lives here.
package user

import (
	"context"
	"time"
)

// User is the domain model for a SHERWOOD platform account.
// Authentication is wallet-signature based; there is no password.
type User struct {
	ID          string
	Address     string    // EIP-55 checksummed wallet address — unique
	DisplayName *string   // nullable until set
	AvatarURL   *string   // nullable until set
	CreatedAt   time.Time
	UpdatedAt   time.Time
	IsDeleted   bool
}

// Repository defines all persistence operations for User aggregates.
// Implementations live in internal/repository and inject a *pgxpool.Pool.
type Repository interface {
	// GetByID returns the user with the given internal UUID.
	// Returns apierr.NotFound if no row exists.
	GetByID(ctx context.Context, id string) (*User, error)

	// GetByAddress returns the user whose primary address matches.
	// Returns apierr.NotFound if no row exists.
	GetByAddress(ctx context.Context, address string) (*User, error)

	// Create persists a new user record and returns the created model.
	Create(ctx context.Context, u *User) (*User, error)

	// Update applies partial updates to a user profile.
	// Only non-nil pointer fields in patch are written.
	Update(ctx context.Context, id string, patch UpdatePatch) (*User, error)

	// SoftDelete marks a user as deleted without removing the row.
	SoftDelete(ctx context.Context, id string) error
}

// UpdatePatch carries the subset of fields that may be changed on a profile.
// A nil pointer means "leave unchanged".
type UpdatePatch struct {
	DisplayName *string
	AvatarURL   *string
}
