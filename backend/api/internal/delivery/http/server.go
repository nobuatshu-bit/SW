package http

import (
	"context"
	"net/http"
	"strings"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"

	"github.com/sherwood-labs/sherwood/backend/api/internal/application/health"
	"github.com/sherwood-labs/sherwood/backend/api/internal/config"
)

const ErrServerClosed = http.ErrServerClosed

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

type pinger interface {
	Ping(ctx context.Context) error
}

func NewRouter(cfg config.Config, database, cache pinger) *gin.Engine {
	if cfg.Environment == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.New()
	router.Use(gin.Logger(), gin.Recovery(), cors.New(cors.Config{
		AllowOrigins:     strings.Split(cfg.CORSOrigins, ","),
		AllowMethods:     []string{http.MethodGet, http.MethodPost, http.MethodPut, http.MethodPatch, http.MethodDelete, http.MethodOptions},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
		MaxAge:           12 * time.Hour,
	}))

	healthService := health.NewService(database, cache)
	router.GET("/health", func(ctx *gin.Context) {
		ctx.JSON(http.StatusOK, healthService.Check(ctx.Request.Context()))
	})

	return router
}
