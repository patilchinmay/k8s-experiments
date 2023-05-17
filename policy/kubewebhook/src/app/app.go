package app

import (
	"net/http"

	kwhhttp "github.com/slok/kubewebhook/v2/pkg/http"
	kwhlog "github.com/slok/kubewebhook/v2/pkg/log"

	mutating "github.com/patilchinmay/k8s-experiments/policy/kubewebhook/src/app/mutating"
)

func New(logger kwhlog.Logger) (http.Handler, error) {

	mutatingWebhook, err := mutating.New(logger)
	if err != nil {
		return nil, err
	}

	mutatingWebhookHandler, err := kwhhttp.HandlerFor(kwhhttp.HandlerConfig{Webhook: mutatingWebhook, Logger: logger})
	if err != nil {
		return nil, err
	}

	mux := http.NewServeMux()
	mux.Handle("/health", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {}))
	mux.Handle("/v1/webhooks/mutating/pod", mutatingWebhookHandler)

	return mux, nil
}
