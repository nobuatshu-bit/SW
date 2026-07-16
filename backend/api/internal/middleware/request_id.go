// Package middleware provides Gin middleware functions for the SHERWOOD API.
// Each middleware is a single exported function returning gin.HandlerFunc,
// keeping the package free of global state.
package middleware

import (
	"crypto/rand"
	"encoding/hex"

	"github.com/gin-gonic/gin"
)

const RequestIDHeader = "X-Request-ID"

// RequestID injects a unique request identifier into every request.
// If the client already supplies X-Request-ID it is forwarded as-is;
// otherwise a cryptographically random 16-byte hex string is generated.
// The final ID is written back into the response header so clients can
// correlate logs with their own request tracking.
func RequestID() gin.HandlerFunc {
	return func(c *gin.Context) {
		id := c.GetHeader(RequestIDHeader)
		if id == "" {
			id = generateID()
		}
		c.Set(RequestIDHeader, id)
		c.Header(RequestIDHeader, id)
		c.Next()
	}
}

// GetRequestID retrieves the request ID attached by the RequestID middleware.
// Returns an empty string if the middleware was not applied.
func GetRequestID(c *gin.Context) string {
	id, _ := c.Get(RequestIDHeader)
	s, _ := id.(string)
	return s
}

func generateID() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}
