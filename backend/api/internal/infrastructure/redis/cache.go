package redis

import (
	"context"
	"time"
)

// Cache is the application-level caching abstraction backed by Redis.
// Handlers and services depend on this interface, not on *Client directly,
// keeping business logic free of Redis-specific types.
//
// All keys are namespaced by the caller (e.g. "session:nonce:<addr>")
// to prevent collisions between different subsystems.
type Cache interface {
	// Get retrieves the string value stored at key.
	// Returns ("", false, nil) if the key does not exist.
	Get(ctx context.Context, key string) (string, bool, error)

	// Set stores value at key with the given TTL.
	// A zero TTL means the key persists indefinitely.
	Set(ctx context.Context, key string, value string, ttl time.Duration) error

	// Del removes the given keys. Missing keys are silently ignored.
	Del(ctx context.Context, keys ...string) error

	// Exists reports whether key is present in the cache.
	Exists(ctx context.Context, key string) (bool, error)

	// Expire resets the TTL on an existing key.
	// Returns false if the key does not exist.
	Expire(ctx context.Context, key string, ttl time.Duration) (bool, error)

	// Ping verifies the Redis connection is alive.
	// Satisfies the health.Dependency interface.
	Ping(ctx context.Context) error
}
