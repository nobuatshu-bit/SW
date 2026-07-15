package redis

import (
	"context"
	"fmt"

	goredis "github.com/redis/go-redis/v9"
)

type Client struct {
	client *goredis.Client
}

func Connect(ctx context.Context, redisURL string) (*Client, error) {
	options, err := goredis.ParseURL(redisURL)
	if err != nil {
		return nil, fmt.Errorf("parse redis URL: %w", err)
	}
	client := goredis.NewClient(options)
	if err := client.Ping(ctx).Err(); err != nil {
		_ = client.Close()
		return nil, fmt.Errorf("ping redis: %w", err)
	}

	return &Client{client: client}, nil
}

func (client *Client) Ping(ctx context.Context) error { return client.client.Ping(ctx).Err() }
func (client *Client) Close() error                    { return client.client.Close() }
