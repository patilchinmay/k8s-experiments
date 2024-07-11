package main

import (
	"context"
	"time"

	"sigs.k8s.io/controller-runtime/pkg/log"
)

type MyRunnable struct {
	interval time.Duration
}

func (r *MyRunnable) Start(ctx context.Context) error {
	log := log.FromContext(ctx) // Get the logger from the context

	ticker := time.NewTicker(r.interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return nil
		case <-ticker.C:
			log.Info("Runnable", "Time", time.Now().Format(time.RFC1123))
		}
	}
}
