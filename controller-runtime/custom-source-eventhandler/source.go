package main

import (
	"context"
	"time"

	"github.com/benbjohnson/clock"
	"github.com/go-logr/logr"
	"github.com/google/uuid"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"sigs.k8s.io/controller-runtime/pkg/event"
)

// Define an ExternalEvent
type ExternalEvent struct {
	JobID string `json:"id"`
}

type ExternalEventSource struct {
	clock          clock.Clock
	tickerInterval time.Duration
	log            logr.Logger
}

func NewExternalEventSource(log logr.Logger) *ExternalEventSource {
	return &ExternalEventSource{
		clock:          clock.New(),
		tickerInterval: tickerInterval,
		log:            log,
	}
}

func (s *ExternalEventSource) Fetch(ctx context.Context) <-chan event.GenericEvent {
	eventsCh := make(chan event.GenericEvent)

	// Create a ticker
	ticker := s.clock.Ticker(s.tickerInterval)

	go func() {
		defer ticker.Stop()
		defer close(eventsCh)

		// Simulate work and block the function
		for {
			select {

			case t := <-ticker.C:
				s.log.Info("tick", "at", t)
				// Simulate work and sending a response
				e := &ExternalEvent{
					JobID: uuid.NewString(),
				}

				ge := event.GenericEvent{
					Object: &unstructured.Unstructured{
						Object: map[string]any{
							// "apiVersion": "batch/v1",
							// "kind":       "Job",
							"metadata": map[string]any{
								"name":      "batch-" + e.JobID,
								"namespace": "default",
							},
						},
					},
				}
				select {
				case eventsCh <- ge:
					// GenericEvent sent successfully
				case <-ctx.Done():
					s.log.Info("context expired while trying to send, exiting...")
					return
				}

			case <-ctx.Done():
				s.log.Info("context expired, exiting...")
				return
			}
		}
	}()

	return eventsCh
}
