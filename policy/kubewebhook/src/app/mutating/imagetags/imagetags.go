package imagetags

import (
	"context"
	"strings"

	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

	kwhlog "github.com/slok/kubewebhook/v2/pkg/log"
	kwmodel "github.com/slok/kubewebhook/v2/pkg/model"
	kwhmutating "github.com/slok/kubewebhook/v2/pkg/webhook/mutating"
)

var (
	_ kwhmutating.Mutator = (*ImageTags)(nil)
)

type ImageTags struct {
	Logger kwhlog.Logger
}

func changeImageTagToLatest(image string) string {

	imageParts := strings.Split(image, ":")
	wantedTag := "latest"

	if len(imageParts) == 1 {
		// e.g. ngnix,
		imageParts = append(imageParts, wantedTag)
	} else {
		// e.g. ngnix:latest, ngnix:1.1.1
		if !strings.Contains(imageParts[1], wantedTag) {
			imageParts[1] = wantedTag
		}
	}

	return strings.Join(imageParts, ":")
}

func (i *ImageTags) Mutate(
	ctx context.Context,
	ar *kwmodel.AdmissionReview,
	obj metav1.Object,
) (result *kwhmutating.MutatorResult, err error) {

	pod, ok := obj.(*corev1.Pod)
	if !ok {
		// If not a pod just continue the mutation chain(if there is one) and don't do nothing.
		return &kwhmutating.MutatorResult{}, nil
	}

	updateContainers := func(path string, containers []corev1.Container) {
		for idx, c := range containers {

			i.Logger.Debugf("%s/%d/image = %s", path, idx, c.Image)

			oldImage := c.Image

			updatedImageTag := changeImageTagToLatest(c.Image)

			containers[idx].Image = updatedImageTag

			if oldImage != updatedImageTag {
				i.Logger.Infof("Image updated: %s -> %s", c.Image, updatedImageTag)
			}
		}
	}
	updateContainers("/spec/initContainers", pod.Spec.InitContainers)
	updateContainers("/spec/containers", pod.Spec.Containers)

	return &kwhmutating.MutatorResult{
		MutatedObject: pod,
	}, nil
}
