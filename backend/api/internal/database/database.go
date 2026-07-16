// Package database provides the PostgreSQL connection manager and the database
// transaction manager used across the application layer.
//
// Connection lifecycle:
//
//	db, err := database.Connect(ctx, cfg.DatabaseURL)
//	// ...
//	defer db.Close()
//
// Transactional operations:
//
//	err := db.WithTx(ctx, func(tx pgx.Tx) error {
//	    // use tx for all queries in this unit of work
//	    return nil
//	})
package database

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// DB wraps a pgxpool.Pool and adds application-level helpers.
// All repository implementations receive a *DB via dependency injection.
type DB struct {
	pool *pgxpool.Pool
}

// Connect creates a new pgxpool connection pool, verifies reachability with
// a ping, and returns a ready-to-use *DB.
func Connect(ctx context.Context, dsn string) (*DB, error) {
	cfg, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		return nil, fmt.Errorf("parse database DSN: %w", err)
	}

	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		return nil, fmt.Errorf("create connection pool: %w", err)
	}

	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("ping database: %w", err)
	}

	return &DB{pool: pool}, nil
}

// Pool returns the underlying pgxpool.Pool for use in repository constructors.
// Repositories should accept a *pgxpool.Pool, not a *DB, to remain testable
// via pgxmock.
func (db *DB) Pool() *pgxpool.Pool { return db.pool }

// Ping checks whether the database is reachable. Satisfies the health.Dependency interface.
func (db *DB) Ping(ctx context.Context) error { return db.pool.Ping(ctx) }

// Close releases all connections in the pool. Call via defer in main.
func (db *DB) Close() { db.pool.Close() }

// WithTx executes fn inside a serialisable transaction. If fn returns a
// non-nil error the transaction is rolled back; otherwise it is committed.
// The provided context is used for both the Begin and Commit/Rollback calls.
func (db *DB) WithTx(ctx context.Context, fn func(pgx.Tx) error) error {
	tx, err := db.pool.BeginTx(ctx, pgx.TxOptions{
		IsoLevel: pgx.Serializable,
	})
	if err != nil {
		return fmt.Errorf("begin transaction: %w", err)
	}

	if err := fn(tx); err != nil {
		if rbErr := tx.Rollback(ctx); rbErr != nil {
			return fmt.Errorf("rollback failed (%w) after: %w", rbErr, err)
		}
		return err
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit transaction: %w", err)
	}
	return nil
}
