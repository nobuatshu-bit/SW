package database

import (
	"context"
	"fmt"
)

// MigrationRunner applies database schema migrations in order.
// Sprint 3 will integrate golang-migrate/migrate with embedded SQL files.
// The interface is defined here so the main.go wiring does not change when
// the real implementation is added.
type MigrationRunner interface {
	// Up applies all pending migrations.
	Up(ctx context.Context) error

	// Version returns the current schema version and whether a dirty state exists.
	Version() (version uint, dirty bool, err error)
}

// NoOpMigrationRunner satisfies MigrationRunner without performing any work.
// Used during development when migrations are applied manually via psql.
type NoOpMigrationRunner struct{}

func (NoOpMigrationRunner) Up(_ context.Context) error               { return nil }
func (NoOpMigrationRunner) Version() (uint, bool, error)             { return 0, false, nil }

// NewMigrationRunner returns the appropriate runner for the environment.
// In Sprint 3, the real implementation using golang-migrate/v4 will be returned.
func NewMigrationRunner(_ *DB) MigrationRunner {
	return NoOpMigrationRunner{}
}

// RunMigrations is a convenience wrapper that calls runner.Up and wraps the error.
func RunMigrations(ctx context.Context, runner MigrationRunner) error {
	if err := runner.Up(ctx); err != nil {
		return fmt.Errorf("apply database migrations: %w", err)
	}
	return nil
}
