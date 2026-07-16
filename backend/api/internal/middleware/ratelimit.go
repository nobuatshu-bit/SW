package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/sherwood-labs/sherwood/backend/api/pkg/apierr"
)

// RateLimitConfig holds per-route rate-limit parameters.
// Sprint 3 will implement token-bucket enforcement backed by Redis.
type RateLimitConfig struct {
	// RequestsPerMinute is the maximum number of requests allowed per client
	// IP address within a 60-second sliding window.
	RequestsPerMinute int
}

// DefaultRateLimitConfig returns a safe default for public endpoints.
func DefaultRateLimitConfig() RateLimitConfig {
	return RateLimitConfig{RequestsPerMinute: 60}
}

// AuthRateLimitConfig returns a conservative limit for auth endpoints to
// mitigate brute-force and replay attacks.
func AuthRateLimitConfig() RateLimitConfig {
	return RateLimitConfig{RequestsPerMinute: 10}
}

// RateLimit is a placeholder rate-limiting middleware.
// In Sprint 3 this will be replaced with Redis-backed token-bucket enforcement.
// Until then it passes all requests through, preserving the middleware chain
// shape so call sites do not need to change.
func RateLimit(_ RateLimitConfig) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Sprint 3: check Redis for the client's request count within the
		// sliding window and abort with 429 if the limit is exceeded.
		c.Next()
	}
}

// tooManyRequests returns the standard 429 response.
// Called by the Sprint 3 implementation; defined here to keep the error
// shape consistent and avoid future import cycles.
func tooManyRequests(c *gin.Context) {
	c.AbortWithStatusJSON(
		http.StatusTooManyRequests,
		errorResponse(apierr.New(
			http.StatusTooManyRequests,
			"RATE_LIMIT_EXCEEDED",
			"too many requests — please slow down",
		)),
	)
}
