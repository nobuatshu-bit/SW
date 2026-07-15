package main

import (
	"context"
	"errors"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"

	"github.com/sherwood-labs/sherwood/backend/api/internal/config"
	"github.com/sherwood-labs/sherwood/backend/api/internal/delivery/http"
	"github.com/sherwood-labs/sherwood/backend/api/internal/infrastructure/postgres"
	"github.com/sherwood-labs/sherwood/backend/api/internal/infrastructure/redis"
)

func main() {
	log.Logger = zerolog.New(os.Stdout).With().Timestamp().Logger()

	ctx := context.Background()
	cfg, err := config.Load(ctx)
	if err != nil {
		log.Fatal().Err(err).Msg("load configuration")
	}

	database, err := postgres.Connect(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatal().Err(err).Msg("connect to postgres")
	}
	defer database.Close()

	cache, err := redis.Connect(ctx, cfg.RedisURL)
	if err != nil {
		log.Fatal().Err(err).Msg("connect to redis")
	}
	defer cache.Close()

	router := http.NewRouter(cfg, database, cache)
	server := http.NewServer(cfg.HTTPAddress, router)

	go func() {
		log.Info().Str("address", cfg.HTTPAddress).Msg("starting HTTP server")
		if serveErr := server.ListenAndServe(); serveErr != nil && !errors.Is(serveErr, http.ErrServerClosed) {
			log.Fatal().Err(serveErr).Msg("HTTP server failed")
		}
	}()

	signalContext, stop := signal.NotifyContext(ctx, syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	<-signalContext.Done()

	shutdownContext, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := server.Shutdown(shutdownContext); err != nil {
		log.Error().Err(err).Msg("graceful shutdown failed")
	}
}
