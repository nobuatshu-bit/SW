package health

import (
	"context"
	"time"

	"github.com/sherwood-labs/sherwood/backend/api/internal/domain/health"
)

type Service struct {
	database health.Dependency
	cache    health.Dependency
}

type Response struct {
	Status    string        `json:"status"`
	Service   string        `json:"service"`
	Timestamp time.Time     `json:"timestamp"`
	Checks    health.Status `json:"checks"`
}

func NewService(database, cache health.Dependency) Service {
	return Service{database: database, cache: cache}
}

func (service Service) Check(ctx context.Context) Response {
	return Response{
		Status:    "ok",
		Service:   "sherwood-api",
		Timestamp: time.Now().UTC(),
		Checks:    health.Check(ctx, service.database, service.cache),
	}
}
