package config

import (
	"context"
	"fmt"

	"github.com/sethvargo/go-envconfig"
)

type Config struct {
	Environment string `env:"APP_ENV,default=development"`
	HTTPAddress string `env:"HTTP_ADDRESS,default=:8080"`
	DatabaseURL string `env:"DATABASE_URL,required"`
	RedisURL    string `env:"REDIS_URL,required"`
	CORSOrigins string `env:"CORS_ORIGINS,default=http://localhost:3000"`
}

func Load(ctx context.Context) (Config, error) {
	var config Config
	if err := envconfig.Process(ctx, &config); err != nil {
		return Config{}, fmt.Errorf("process environment: %w", err)
	}

	return config, nil
}
