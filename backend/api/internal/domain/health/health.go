package health

import "context"

type Dependency interface {
	Ping(context.Context) error
}

type Status struct {
	Postgres bool `json:"postgres"`
	Redis    bool `json:"redis"`
}

func Check(ctx context.Context, database, cache Dependency) Status {
	return Status{
		Postgres: database.Ping(ctx) == nil,
		Redis:    cache.Ping(ctx) == nil,
	}
}
