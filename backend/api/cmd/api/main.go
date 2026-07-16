package main

import (
	"context"
	"errors"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/sherwood-labs/sherwood/backend/api/internal/config"
	"github.com/sherwood-labs/sherwood/backend/api/internal/database"
	delivery "github.com/sherwood-labs/sherwood/backend/api/internal/delivery/http"
	"github.com/sherwood-labs/sherwood/backend/api/internal/infrastructure/redis"
	"github.com/sherwood-labs/sherwood/backend/api/pkg/logger"
)

func main() {
	ctx := context.Background()

	// ── Configuration ─────────────────────────────────────────────────────────
	cfg, err := config.Load(ctx)
	if err != nil {
		// Logger is not yet initialised; fall back to os.Stderr.
		os.Stderr.WriteString("FATAL: load configuration: " + err.Error() + "\n")
		os.Exit(1)
	}

	// ── Logger ────────────────────────────────────────────────────────────────
	var log logger.Logger
	if cfg.IsProduction() {
		log = logger.New(cfg.LogLevel, os.Stdout)
	} else {
		log = logger.NewDevelopment()
	}

	log.Info("configuration loaded",
		logger.F("env", cfg.Environment),
		logger.F("chain_id", cfg.ChainID),
		logger.F("log_level", cfg.LogLevel),
	)

	// ── Database ──────────────────────────────────────────────────────────────
	db, err := database.Connect(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatal("connect to postgres", err)
		os.Exit(1)
	}
	defer db.Close()
	log.Info("postgres connected")

	// Run migrations (no-op in development until Sprint 3 integrates migrate).
	migrationRunner := database.NewMigrationRunner(db)
	if err := database.RunMigrations(ctx, migrationRunner); err != nil {
		log.Fatal("run database migrations", err)
		os.Exit(1)
	}

	// ── Redis ─────────────────────────────────────────────────────────────────
	cache, err := redis.Connect(ctx, cfg.RedisURL)
	if err != nil {
		log.Fatal("connect to redis", err)
		os.Exit(1)
	}
	defer func() {
		if closeErr := cache.Close(); closeErr != nil {
			log.Error("close redis connection", closeErr)
		}
	}()
	log.Info("redis connected")

	// ── HTTP server ───────────────────────────────────────────────────────────
	router := delivery.NewRouter(delivery.RouterDeps{
		Config: cfg,
		DB:     db,
		Cache:  cache,
		Log:    log,
	})

	server := delivery.NewServer(cfg.HTTPAddress, router)

	go func() {
		log.Info("HTTP server starting", logger.F("address", cfg.HTTPAddress))
		if serveErr := server.ListenAndServe(); serveErr != nil && !errors.Is(serveErr, delivery.ErrServerClosed) {
			log.Fatal("HTTP server failed", serveErr)
			os.Exit(1)
		}
	}()

	// ── Graceful shutdown ─────────────────────────────────────────────────────
	sigCtx, stop := signal.NotifyContext(ctx, syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	<-sigCtx.Done()

	log.Info("shutdown signal received")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	if err := server.Shutdown(shutdownCtx); err != nil {
		log.Error("graceful shutdown failed", err)
	} else {
		log.Info("HTTP server stopped cleanly")
	}
}
