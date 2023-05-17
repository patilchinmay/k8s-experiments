package mutating

import (
	"github.com/patilchinmay/k8s-experiments/policy/kubewebhook/src/app/mutating/addlabel"
	"github.com/patilchinmay/k8s-experiments/policy/kubewebhook/src/app/mutating/imagetags"
	kwhlog "github.com/slok/kubewebhook/v2/pkg/log"
	kwhwebhook "github.com/slok/kubewebhook/v2/pkg/webhook"
	kwhmutating "github.com/slok/kubewebhook/v2/pkg/webhook/mutating"
)

func New(
	logger kwhlog.Logger,
) (kwhwebhook.Webhook, error) {

	mutators := []kwhmutating.Mutator{
		&addlabel.AddLabel{
			Logger: logger,
		},
		&imagetags.ImageTags{
			Logger: logger,
		},
	}

	return kwhmutating.NewWebhook(kwhmutating.WebhookConfig{
		ID:      "mutate-pod",
		Mutator: kwhmutating.NewChain(logger, mutators...),
		Logger:  logger,
	})
}
