package middleware

import (
	"time"

	"github.com/gin-gonic/gin"

	"github.com/sherwood-labs/sherwood/backend/api/pkg/logger"
)

// Logger returns a Gin middleware that writes a structured access log entry
// for every request after it completes. The entry includes: method, path,
// status code, latency, client IP, and the request ID set by RequestID().
func Logger(log logger.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		if raw := c.Request.URL.RawQuery; raw != "" {
			path += "?" + raw
		}

		c.Next()

		latency := time.Since(start)
		status := c.Writer.Status()
		requestID := GetRequestID(c)

		fields := []logger.Field{
			logger.F("status", status),
			logger.F("method", c.Request.Method),
			logger.F("path", path),
			logger.F("latency_ms", latency.Milliseconds()),
			logger.F("client_ip", c.ClientIP()),
			logger.F("request_id", requestID),
			logger.F("bytes_out", c.Writer.Size()),
		}

		switch {
		case status >= 500:
			log.Error("request completed", nil, fields...)
		case status >= 400:
			log.Warn("request completed", fields...)
		default:
			log.Info("request completed", fields...)
		}
	}
}
