package middleware

import (
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/sherwood-labs/sherwood/backend/api/pkg/apierr"
	"github.com/sherwood-labs/sherwood/backend/api/pkg/logger"
)

// Recovery returns a Gin middleware that catches panics, logs a stack trace,
// and responds with a structured 500 error instead of crashing the process.
// It replaces gin.Recovery() to ensure the response uses the standard
// SHERWOOD error envelope.
func Recovery(log logger.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if r := recover(); r != nil {
				err := fmt.Errorf("panic: %v", r)
				log.Error("recovered from panic", err,
					logger.F("request_id", GetRequestID(c)),
					logger.F("method", c.Request.Method),
					logger.F("path", c.Request.URL.Path),
				)
				apiErr := apierr.Internal(err)
				c.AbortWithStatusJSON(http.StatusInternalServerError, errorResponse(apiErr))
			}
		}()
		c.Next()
	}
}
