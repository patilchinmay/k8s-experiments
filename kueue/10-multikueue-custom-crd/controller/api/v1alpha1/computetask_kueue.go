// Package v1alpha1 — Kueue external framework integration for ComputeTask.
//
// Kueue's "externalFrameworks" feature (feature-gated as ExternalFrameworks) lets
// third-party controllers register custom CRDs so that Kueue manages admission for
// them.  The controller must:
//
//  1. Implement the sigs.k8s.io/kueue/pkg/controller/jobframework.GenericJob interface
//     so Kueue can extract resource requirements and manage suspend/resume.
//  2. Call jobframework.RegisterIntegration() during controller setup.
//  3. Set the kueue.x-k8s.io/queue-name label on every ComputeTask it wants queued.
//
// Kueue will then:
//   - Create a shadow Workload object alongside each ComputeTask.
//   - Gate admission via the Workload lifecycle.
//   - (With MultiKueue) dispatch the Workload + a mirrored ComputeTask to a worker cluster.
//   - Propagate worker Workload status back to the manager Workload.
//
// The controller watches ComputeTask; when spec.suspend flips to false the backing
// Pod is created.
package v1alpha1

import (
	"context"
	"fmt"

	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/schema"
	"k8s.io/utils/ptr"
	kueuev1beta1 "sigs.k8s.io/kueue/apis/kueue/v1beta1"
	"sigs.k8s.io/kueue/pkg/controller/jobframework"
	"sigs.k8s.io/kueue/pkg/podset"
)

// Compile-time interface check.
var _ jobframework.GenericJob = (*ComputeTaskWrapper)(nil)

// ComputeTaskWrapper adapts *ComputeTask to the jobframework.GenericJob interface.
type ComputeTaskWrapper struct {
	ComputeTask
}

// Object returns the underlying runtime.Object (required by GenericJob).
func (w *ComputeTaskWrapper) Object() runtime.Object { return &w.ComputeTask }

// IsSuspended returns true when the controller should not create the Pod yet.
func (w *ComputeTaskWrapper) IsSuspended() bool { return w.Spec.Suspend }

// Suspend sets or clears the suspend field.
func (w *ComputeTaskWrapper) Suspend() { w.Spec.Suspend = true }

// RunWithPodSetsInfo unsuspends the task (Kueue calls this when the Workload is admitted).
// nodeSelectors carries Kueue's scheduling hints (topology, flavors); ComputeTask
// ignores them for simplicity — the worker controller just creates a plain Pod.
func (w *ComputeTaskWrapper) RunWithPodSetsInfo(_ []podset.PodSetInfo) error {
	w.Spec.Suspend = false
	return nil
}

// RestorePodSetsInfo is called when Kueue rolls back an admission.  Nothing to restore.
func (w *ComputeTaskWrapper) RestorePodSetsInfo(_ []podset.PodSetInfo) bool { return false }

// Finished reports whether the task has reached a terminal state and optionally a message.
func (w *ComputeTaskWrapper) Finished() (metav1.Condition, bool) {
	switch w.Status.Phase {
	case ComputeTaskPhaseSucceeded:
		return metav1.Condition{
			Type:    kueuev1beta1.WorkloadFinished,
			Status:  metav1.ConditionTrue,
			Reason:  "Succeeded",
			Message: "ComputeTask completed successfully",
		}, true
	case ComputeTaskPhaseFailed:
		return metav1.Condition{
			Type:    kueuev1beta1.WorkloadFinished,
			Status:  metav1.ConditionTrue,
			Reason:  "Failed",
			Message: "ComputeTask Pod failed",
		}, true
	default:
		return metav1.Condition{}, false
	}
}

// PodSets describes the resource requirements Kueue should account for.
// A ComputeTask maps to a single pod-set with 1 replica consuming 100m CPU / 64Mi.
func (w *ComputeTaskWrapper) PodSets() []kueuev1beta1.PodSet {
	return []kueuev1beta1.PodSet{
		{
			Name:  "task",
			Count: ptr.To[int32](1),
			Template: corev1.PodTemplateSpec{
				Spec: corev1.PodSpec{
					Containers: []corev1.Container{
						{
							Name:  "task",
							Image: "busybox:1.36",
							Resources: corev1.ResourceRequirements{
								Requests: corev1.ResourceList{
									corev1.ResourceCPU:    resource.MustParse("100m"),
									corev1.ResourceMemory: resource.MustParse("64Mi"),
								},
							},
						},
					},
				},
			},
		},
	}
}

// IsActive returns true if the task is not yet in a terminal state.
func (w *ComputeTaskWrapper) IsActive() bool {
	return w.Status.Phase != ComputeTaskPhaseSucceeded &&
		w.Status.Phase != ComputeTaskPhaseFailed
}

// PodsReady returns true when the backing Pod is Running (best-effort check).
func (w *ComputeTaskWrapper) PodsReady() bool {
	return w.Status.Phase == ComputeTaskPhaseRunning
}

// GVK returns the GroupVersionKind of ComputeTask.
func (w *ComputeTaskWrapper) GVK() schema.GroupVersionKind {
	return schema.GroupVersionKind{
		Group:   GroupVersion.Group,
		Version: GroupVersion.Version,
		Kind:    "ComputeTask",
	}
}

// NewComputeTaskWrapper creates a ComputeTaskWrapper from a ComputeTask.
func NewComputeTaskWrapper(ct *ComputeTask) *ComputeTaskWrapper {
	return &ComputeTaskWrapper{ComputeTask: *ct}
}

// ComputeTaskWrapperConstructor is the factory function used by Kueue's framework registry.
func ComputeTaskWrapperConstructor() jobframework.GenericJob {
	return &ComputeTaskWrapper{}
}

// RegisterComputeTaskIntegration registers the ComputeTask integration with Kueue's job framework.
// Call this during controller-manager startup, before mgr.Start().
func RegisterComputeTaskIntegration(ctx context.Context) error {
	if err := jobframework.RegisterIntegration("compute.example.com/computetask", jobframework.IntegrationCallbacks{
		NewJob: ComputeTaskWrapperConstructor,
		SetupIndexes: func(_ context.Context, _ interface{}) error {
			return nil
		},
		NewReconciler:          nil, // we supply our own reconciler
		SetupWebhook:           nil,
		JobType:                &ComputeTask{},
		AddToScheme:            AddToScheme,
		IsManagingObjectsOwner: isManagingObjectsOwner,
		MultiKueueAdapter:      nil, // default MultiKueue adapter handles CR copy
		DependencyList:         nil,
	}); err != nil {
		return fmt.Errorf("registering computetask integration: %w", err)
	}
	return nil
}

func isManagingObjectsOwner(obj metav1.Object) bool {
	ownerRefs := obj.GetOwnerReferences()
	for _, ref := range ownerRefs {
		if ref.APIVersion == GroupVersion.String() && ref.Kind == "ComputeTask" {
			return true
		}
	}
	return false
}
