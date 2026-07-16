// Package config loads and validates all application configuration from
// environment variables. Every field is explicitly typed and documented.
// Unknown or missing required variables cause a hard failure at startup,
// preventing silent misconfigurations in production.
package config

import (
	"context"
	"fmt"
	"strings"

	"github.com/sethvargo/go-envconfig"
)

// Config holds every runtime parameter for the SHERWOOD API process.
// Fields tagged `required` will cause Load to return an error if absent.
// Fields with `default` fall back to the specified value.
type Config struct {
	// ── Server ───────────────────────────────────────────────────────────────

	// Environment controls logging verbosity and Gin mode.
	// Accepted values: development | staging | production
	Environment string `env:"APP_ENV,default=development"`

	// HTTPAddress is the TCP address the HTTP server listens on.
	HTTPAddress string `env:"HTTP_ADDRESS,default=:8080"`

	// CORSOrigins is a comma-separated list of allowed CORS origins.
	CORSOrigins string `env:"CORS_ORIGINS,default=http://localhost:3000"`

	// ── Data stores ──────────────────────────────────────────────────────────

	// DatabaseURL is the full pgx connection string.
	// Example: postgres://user:pass@host:5432/dbname?sslmode=require
	DatabaseURL string `env:"DATABASE_URL,required"`

	// RedisURL is the full Redis connection string.
	// Example: redis://:password@host:6379/0
	RedisURL string `env:"REDIS_URL,required"`

	// ── Auth ─────────────────────────────────────────────────────────────────

	// JWTSecret is the HMAC-SHA256 signing secret for session tokens.
	// Must be at least 32 bytes in production.
	JWTSecret string `env:"JWT_SECRET,required"`

	// JWTExpiryHours is the lifetime of an issued JWT in hours.
	JWTExpiryHours int `env:"JWT_EXPIRY_HOURS,default=24"`

	// ── Blockchain ───────────────────────────────────────────────────────────

	// BaseRPCURL is the JSON-RPC endpoint used by the event indexer.
	// Example: https://sepolia.base.org or wss://sepolia.base.org
	BaseRPCURL string `env:"BASE_RPC_URL,required"`

	// ChainID is the EVM chain ID the API operates on.
	// 84532 = Base Sepolia, 8453 = Base Mainnet.
	ChainID int64 `env:"CHAIN_ID,default=84532"`

	// ── Observability ────────────────────────────────────────────────────────

	// LogLevel controls the minimum log level emitted.
	// Accepted values: debug | info | warn | error
	LogLevel string `env:"LOG_LEVEL,default=info"`
}

// Load reads all environment variables into a Config, applies defaults, and
// runs structural validation. It returns a non-nil error if any required
// variable is absent or any value fails validation.
func Load(ctx context.Context) (Config, error) {
	var cfg Config
	if err := envconfig.Process(ctx, &cfg); err != nil {
		return Config{}, fmt.Errorf("process environment variables: %w", err)
	}
	if err := cfg.validate(); err != nil {
		return Config{}, fmt.Errorf("invalid configuration: %w", err)
	}
	return cfg, nil
}

// validate runs domain-level checks that envconfig cannot express as tags.
func (c Config) validate() error {
	validEnvs := map[string]bool{"development": true, "staging": true, "production": true}
	if !validEnvs[c.Environment] {
		return fmt.Errorf("APP_ENV must be one of: development, staging, production; got %q", c.Environment)
	}

	validLevels := map[string]bool{"debug": true, "info": true, "warn": true, "error": true}
	if !validLevels[strings.ToLower(c.LogLevel)] {
		return fmt.Errorf("LOG_LEVEL must be one of: debug, info, warn, error; got %q", c.LogLevel)
	}

	if c.Environment == "production" && len(c.JWTSecret) < 32 {
		return fmt.Errorf("JWT_SECRET must be at least 32 characters in production")
	}

	if c.ChainID != 84532 && c.ChainID != 8453 {
		return fmt.Errorf("CHAIN_ID must be 84532 (Base Sepolia) or 8453 (Base Mainnet); got %d", c.ChainID)
	}

	if c.JWTExpiryHours < 1 || c.JWTExpiryHours > 720 {
		return fmt.Errorf("JWT_EXPIRY_HOURS must be between 1 and 720; got %d", c.JWTExpiryHours)
	}

	return nil
}

// IsProduction reports whether the server is running in production mode.
func (c Config) IsProduction() bool { return c.Environment == "production" }

// CORSOriginList returns CORSOrigins split into a slice, trimming whitespace.
func (c Config) CORSOriginList() []string {
	parts := strings.Split(c.CORSOrigins, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		if trimmed := strings.TrimSpace(p); trimmed != "" {
			out = append(out, trimmed)
		}
	}
	return out
}
