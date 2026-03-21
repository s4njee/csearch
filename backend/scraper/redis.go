package main

import "context"

import "github.com/redis/go-redis/v9"

var (
	newRedisClient = func(opt *redis.Options) redisClient {
		return redis.NewClient(opt)
	}
	redisOptions = redis.ParseURL
)

type redisClient interface {
	Ping(ctx context.Context) *redis.StatusCmd
	Scan(ctx context.Context, cursor uint64, match string, count int64) *redis.ScanCmd
	Del(ctx context.Context, keys ...string) *redis.IntCmd
	Close() error
}
