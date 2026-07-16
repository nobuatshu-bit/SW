package middleware

import (
	"net/http"
	"time"

	gincors "github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

// CORS returns a Gin middleware that applies Cross-Origin Resource Sharing
// headers. Only the origins in the allowedOrigins slice are permitted;
// credentials (cookies, Authorization header) are explicitly allowed so that
// the wallet-auth flow works from browser clients.
func CORS(allowedOrigins []string) gin.HandlerFunc {
	return gincors.New(gincors.Config{
		AllowOrigins: allowedOrigins,
		AllowMethods: []string{
			http.MethodGet,
			http.MethodPost,
			http.MethodPut,
			http.MethodPatch,
			http.MethodDelete,
			http.MethodOptions,
		},
		AllowHeaders: []string{
			"Origin",
			"Content-Type",
			"Authorization",
			RequestIDHeader,
		},
		ExposeHeaders:    []string{"Content-Length", RequestIDHeader},
		AllowCredentials: true,
		MaxAge:           12 * time.Hour,
	})
}
