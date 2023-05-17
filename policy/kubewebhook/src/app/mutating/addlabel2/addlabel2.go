package addlabel2

import (
	"context"

	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

	kwhlog "github.com/slok/kubewebhook/v2/pkg/log"
	kwmodel "github.com/slok/kubewebhook/v2/pkg/model"
	kwhmutating "github.com/slok/kubewebhook/v2/pkg/webhook/mutating"
)

var (
	_ kwhmutating.Mutator = (*AddLabel)(nil)
)

type AddLabel struct {
	Logger kwhlog.Logger
}

func (a *AddLabel) Mutate(
	ctx context.Context,
	ar *kwmodel.AdmissionReview,
	obj metav1.Object,
) (result *kwhmutating.MutatorResult, err error) {
	// mjs, _ := json.Marshal(ar.OriginalAdmissionReview)
	// a.Logger.Debugf("review = %v", string(mjs))

	pod, ok := obj.(*corev1.Pod)
	if !ok {
		// If not a pod just continue the mutation chain(if there is one) and don't do nothing.
		return &kwhmutating.MutatorResult{}, nil
	}

	// Mutate our object with the required annotations.
	if pod.Annotations == nil {
		pod.Annotations = make(map[string]string)
	}
	pod.Annotations["mutated"] = "true"
	pod.Annotations["mutator"] = "pod-annotate"

	a.Logger.Debugf("Added 2 labels")

	return &kwhmutating.MutatorResult{
		MutatedObject: pod,
	}, nil
}
