package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"github.com/sherwood-labs/sherwood/backend/api/pkg/apierr"
)

// ContextKey is the key used to store authenticated claims in gin.Context.
const ContextKeyAuthClaims = "auth_claims"

// AuthClaims holds the validated JWT payload injected by the Auth middleware.
// Expanded in Sprint 3 when JWT signing/verification is implemented.
type AuthClaims struct {
	UserID  string
	Address string
}

// Auth is a placeholder JWT authentication middleware.
// In Sprint 3 this will be replaced with full HMAC-SHA256 JWT verification.
// Currently it validates the Authorization header shape and extracts the
// bearer token, returning 401 for malformed or missing credentials.
//
// When active, the validated AuthClaims are stored in gin.Context under
// ContextKeyAuthClaims and can be retrieved with GetAuthClaims.
func Auth() gin.HandlerFunc {
	return func(c *gin.Context) {
		header := c.GetHeader("Authorization")
		if header == "" {
			c.AbortWithStatusJSON(
				http.StatusUnauthorized,
				errorResponse(apierr.Unauthorized()),
			)
			return
		}

		parts := strings.SplitN(header, " ", 2)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") || strings.TrimSpace(parts[1]) == "" {
			c.AbortWithStatusJSON(
				http.StatusUnauthorized,
				errorResponse(apierr.New(http.StatusUnauthorized, apierr.CodeUnauthenticated, "invalid Authorization header format")),
			)
			return
		}

		// Sprint 3: verify the JWT here and populate real claims.
		// For now we store an empty struct so downstream handlers can call
		// GetAuthClaims without panicking.
		c.Set(ContextKeyAuthClaims, &AuthClaims{})
		c.Next()
	}
}

// GetAuthClaims retrieves the auth claims set by the Auth middleware.
// Returns nil if the middleware was not applied to the route.
func GetAuthClaims(c *gin.Context) *AuthClaims {
	val, exists := c.Get(ContextKeyAuthClaims)
	if !exists {
		return nil
	}
	claims, _ := val.(*AuthClaims)
	return claims
}
