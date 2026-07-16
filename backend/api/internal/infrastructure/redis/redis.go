// Package redis provides the Redis client and the Cache interface implementation
// for the SHERWOOD API. Application code depends on the Cache interface, not
// on the concrete *Client, enabling straightforward in-memory test doubles.
package redis

import (
	"context"
	"errors"
	"fmt"
	"time"

	goredis "github.com/redis/go-redis/v9"
)

// Client wraps go-redis and implements the Cache interface.
type Client struct {
	client *goredis.Client
}

// Connect parses redisURL, creates a client, verifies reachability, and
// returns a *Client that also satisfies the Cache interface.
func Connect(ctx context.Context, redisURL string) (*Client, error) {
	opts, err := goredis.ParseURL(redisURL)
	if err != nil {
		return nil, fmt.Errorf("parse redis URL: %w", err)
	}

	c := goredis.NewClient(opts)
	if err := c.Ping(ctx).Err(); err != nil {
		_ = c.Close()
		return nil, fmt.Errorf("ping redis: %w", err)
	}

	return &Client{client: c}, nil
}

// ── Cache interface implementation ────────────────────────────────────────────

// Get retrieves the value stored at key.
// Returns ("", false, nil) when the key does not exist.
func (c *Client) Get(ctx context.Context, key string) (string, bool, error) {
	val, err := c.client.Get(ctx, key).Result()
	if errors.Is(err, goredis.Nil) {
		return "", false, nil
	}
	if err != nil {
		return "", false, fmt.Errorf("redis GET %q: %w", key, err)
	}
	return val, true, nil
}

// Set stores value at key with the given TTL.
func (c *Client) Set(ctx context.Context, key, value string, ttl time.Duration) error {
	if err := c.client.Set(ctx, key, value, ttl).Err(); err != nil {
		return fmt.Errorf("redis SET %q: %w", key, err)
	}
	return nil
}

// Del removes one or more keys. Missing keys are silently ignored.
func (c *Client) Del(ctx context.Context, keys ...string) error {
	if err := c.client.Del(ctx, keys...).Err(); err != nil {
		return fmt.Errorf("redis DEL: %w", err)
	}
	return nil
}

// Exists reports whether the key is present.
func (c *Client) Exists(ctx context.Context, key string) (bool, error) {
	count, err := c.client.Exists(ctx, key).Result()
	if err != nil {
		return false, fmt.Errorf("redis EXISTS %q: %w", key, err)
	}
	return count > 0, nil
}

// Expire resets the TTL on key. Returns false if the key is absent.
func (c *Client) Expire(ctx context.Context, key string, ttl time.Duration) (bool, error) {
	ok, err := c.client.Expire(ctx, key, ttl).Result()
	if err != nil {
		return false, fmt.Errorf("redis EXPIRE %q: %w", key, err)
	}
	return ok, nil
}

// Ping verifies the connection. Satisfies health.Dependency.
func (c *Client) Ping(ctx context.Context) error {
	if err := c.client.Ping(ctx).Err(); err != nil {
		return fmt.Errorf("redis ping: %w", err)
	}
	return nil
}

// Close releases the Redis connection. Call via defer in main.
func (c *Client) Close() error { return c.client.Close() }
