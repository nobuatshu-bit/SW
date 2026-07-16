// Package http is the HTTP delivery layer for the SHERWOOD API.
// It owns the Gin router, server construction, and route registration.
// Business logic lives in the service layer; handlers only translate between
// HTTP and Go types.
package http

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/sherwood-labs/sherwood/backend/api/internal/config"
	"github.com/sherwood-labs/sherwood/backend/api/internal/database"
	apphealth "github.com/sherwood-labs/sherwood/backend/api/internal/application/health"
	"github.com/sherwood-labs/sherwood/backend/api/internal/infrastructure/redis"
	"github.com/sherwood-labs/sherwood/backend/api/internal/middleware"
	"github.com/sherwood-labs/sherwood/backend/api/pkg/logger"
)

// ErrServerClosed is re-exported so callers do not import net/http directly.
// Must be a var (not const) because http.ErrServerClosed is a pointer value.
var ErrServerClosed = http.ErrServerClosed

// NewServer constructs an *http.Server with production-safe timeouts.
// The returned server is not started; call ListenAndServe in a goroutine.
func NewServer(address string, handler http.Handler) *http.Server {
	return &http.Server{
		Addr:              address,
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       60 * time.Second,
	}
}

// RouterDeps carries the dependencies injected into the router constructor.
// All fields are interfaces so test doubles can be substituted in Sprint 3.
type RouterDeps struct {
	Config   config.Config
	DB       *database.DB
	Cache    redis.Cache
	Log      logger.Logger
}

// NewRouter builds the Gin engine, applies all middleware, and registers
// every route group. Add new route groups here as features are implemented.
func NewRouter(deps RouterDeps) *gin.Engine {
	if deps.Config.IsProduction() {
		gin.SetMode(gin.ReleaseMode)
	}

	r := gin.New()

	// ── Global middleware (applied to every request) ───────────────────────
	r.Use(
		middleware.RequestID(),
		middleware.Recovery(deps.Log),
		middleware.Logger(deps.Log),
		middleware.CORS(deps.Config.CORSOriginList()),
	)

	// ── System routes ──────────────────────────────────────────────────────
	registerSystemRoutes(r, deps)

	// ── API v1 group (future business endpoints) ───────────────────────────
	// v1 := r.Group("/v1")
	// v1.Use(middleware.RateLimit(middleware.DefaultRateLimitConfig()))
	// Sprint 3: register auth, launch, wallet, portfolio, activity routes here.

	return r
}

// registerSystemRoutes mounts operational endpoints that are not versioned
// and are never behind authentication.
func registerSystemRoutes(r *gin.Engine, deps RouterDeps) {
	healthSvc := apphealth.NewService(deps.DB, deps.Cache)

	// GET /health — dependency health check
	r.GET("/health", func(c *gin.Context) {
		resp := healthSvc.Check(c.Request.Context())
		c.JSON(http.StatusOK, resp)
	})

	// GET /version — process metadata
	r.GET("/version", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"success": true,
			"data": gin.H{
				"version":     BuildVersion,
				"commit":      BuildCommit,
				"build_time":  BuildTime,
				"go_version":  GoVersion,
			},
		})
	})

	// 404 handler — returns the standard error envelope
	r.NoRoute(func(c *gin.Context) {
		c.JSON(http.StatusNotFound, gin.H{
			"success": false,
			"error": gin.H{
				"code":    "NOT_FOUND",
				"message": "the requested resource does not exist",
			},
		})
	})

	// 405 handler
	r.NoMethod(func(c *gin.Context) {
		c.JSON(http.StatusMethodNotAllowed, gin.H{
			"success": false,
			"error": gin.H{
				"code":    "METHOD_NOT_ALLOWED",
				"message": "method not allowed",
			},
		})
	})
}

// ── Build metadata (injected via -ldflags at compile time) ────────────────────

// These are package-level vars so they can be set by the linker:
//
//	go build -ldflags "-X .../delivery/http.BuildVersion=1.0.0 ..."
var (
	BuildVersion = "dev"
	BuildCommit  = "unknown"
	BuildTime    = "unknown"
	GoVersion    = "unknown"
)
