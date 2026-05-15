// Package controller implements the ComputeTask controller.
//
// Reconcile loop (worker cluster):
//  1. Fetch the ComputeTask.
//  2. If spec.suspend == true → ensure any existing Pod is deleted; return.
//  3. If spec.suspend == false and no Pod exists → create a Pod that sleeps for
//     spec.durationSeconds.
//  4. Watch Pod phase and propagate it back into ComputeTask.status.
//  5. Set status.workerCluster from the WORKER_CLUSTER_NAME env var (injected by
//     the Deployment manifest at install time).
//
// The status is written by the worker controller.  MultiKueue's status sync
// (built into the Kueue manager) reads the Workload on the worker and reflects
// status changes back to the manager cluster's Workload — and, via the Workload
// owner reference, back to the manager ComputeTask.
package controller

import (
	"context"
	"fmt"
	"os"

	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/equality"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"
	"sigs.k8s.io/controller-runtime/pkg/log"

	computev1alpha1 "github.com/kueue-experiments/computetask-controller/api/v1alpha1"
)

// ComputeTaskReconciler reconciles a ComputeTask object.
type ComputeTaskReconciler struct {
	client.Client
	Scheme      *runtime.Scheme
	ClusterName string // value of WORKER_CLUSTER_NAME env var
}

// +kubebuilder:rbac:groups=compute.example.com,resources=computetasks,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=compute.example.com,resources=computetasks/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=compute.example.com,resources=computetasks/finalizers,verbs=update
// +kubebuilder:rbac:groups="",resources=pods,verbs=get;list;watch;create;update;patch;delete

// Reconcile implements the main reconcile loop.
func (r *ComputeTaskReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx)

	// 1. Fetch the ComputeTask.
	ct := &computev1alpha1.ComputeTask{}
	if err := r.Get(ctx, req.NamespacedName, ct); err != nil {
		if apierrors.IsNotFound(err) {
			return ctrl.Result{}, nil
		}
		return ctrl.Result{}, fmt.Errorf("get ComputeTask: %w", err)
	}

	// 2. If suspended, delete any existing Pod and ensure status reflects Pending.
	if ct.Spec.Suspend {
		if err := r.deletePodIfExists(ctx, ct); err != nil {
			return ctrl.Result{}, err
		}
		return r.updateStatus(ctx, ct, func(s *computev1alpha1.ComputeTaskStatus) {
			s.Phase = computev1alpha1.ComputeTaskPhasePending
			s.StartTime = nil
			s.CompletionTime = nil
			s.PodName = ""
		})
	}

	// 3. Ensure the backing Pod exists.
	pod := &corev1.Pod{}
	podName := podNameFor(ct)
	err := r.Get(ctx, client.ObjectKey{Namespace: ct.Namespace, Name: podName}, pod)
	if apierrors.IsNotFound(err) {
		logger.Info("creating Pod for ComputeTask", "pod", podName)
		newPod := r.buildPod(ct)
		if err2 := controllerutil.SetControllerReference(ct, newPod, r.Scheme); err2 != nil {
			return ctrl.Result{}, fmt.Errorf("set owner reference: %w", err2)
		}
		if err2 := r.Create(ctx, newPod); err2 != nil {
			return ctrl.Result{}, fmt.Errorf("create Pod: %w", err2)
		}
		pod = newPod
	} else if err != nil {
		return ctrl.Result{}, fmt.Errorf("get Pod: %w", err)
	}

	// 4. Map Pod phase → ComputeTask phase and propagate back.
	desiredPhase := podPhaseToTaskPhase(pod.Status.Phase)
	return r.updateStatus(ctx, ct, func(s *computev1alpha1.ComputeTaskStatus) {
		s.Phase = desiredPhase
		s.PodName = podName
		s.WorkerCluster = r.ClusterName
		if pod.Status.StartTime != nil && s.StartTime == nil {
			s.StartTime = pod.Status.StartTime
		}
		if (desiredPhase == computev1alpha1.ComputeTaskPhaseSucceeded ||
			desiredPhase == computev1alpha1.ComputeTaskPhaseFailed) &&
			s.CompletionTime == nil {
			now := metav1.Now()
			s.CompletionTime = &now
		}
	})
}

// updateStatus patches ComputeTask.status iff it has changed.
func (r *ComputeTaskReconciler) updateStatus(
	ctx context.Context,
	ct *computev1alpha1.ComputeTask,
	mutate func(*computev1alpha1.ComputeTaskStatus),
) (ctrl.Result, error) {
	original := ct.Status.DeepCopy()
	mutate(&ct.Status)
	if equality.Semantic.DeepEqual(original, &ct.Status) {
		return ctrl.Result{}, nil
	}
	if err := r.Status().Update(ctx, ct); err != nil {
		return ctrl.Result{}, fmt.Errorf("update ComputeTask status: %w", err)
	}
	return ctrl.Result{}, nil
}

// deletePodIfExists deletes the backing Pod if it exists.
func (r *ComputeTaskReconciler) deletePodIfExists(ctx context.Context, ct *computev1alpha1.ComputeTask) error {
	pod := &corev1.Pod{}
	err := r.Get(ctx, client.ObjectKey{Namespace: ct.Namespace, Name: podNameFor(ct)}, pod)
	if apierrors.IsNotFound(err) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("get Pod for deletion: %w", err)
	}
	if err := r.Delete(ctx, pod); err != nil && !apierrors.IsNotFound(err) {
		return fmt.Errorf("delete Pod: %w", err)
	}
	return nil
}

// buildPod constructs the Pod that performs the compute work.
func (r *ComputeTaskReconciler) buildPod(ct *computev1alpha1.ComputeTask) *corev1.Pod {
	duration := ct.Spec.DurationSeconds
	if duration <= 0 {
		duration = 60
	}
	return &corev1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			Name:      podNameFor(ct),
			Namespace: ct.Namespace,
			Labels: map[string]string{
				"compute.example.com/computetask": ct.Name,
			},
		},
		Spec: corev1.PodSpec{
			RestartPolicy: corev1.RestartPolicyNever,
			Containers: []corev1.Container{
				{
					Name:    "task",
					Image:   "busybox:1.36",
					Command: []string{"sh", "-c", fmt.Sprintf("echo 'ComputeTask %s/%s starting'; sleep %d; echo 'done'", ct.Namespace, ct.Name, duration)},
					Resources: corev1.ResourceRequirements{
						Requests: corev1.ResourceList{
							corev1.ResourceCPU:    resource.MustParse("100m"),
							corev1.ResourceMemory: resource.MustParse("64Mi"),
						},
						Limits: corev1.ResourceList{
							corev1.ResourceCPU:    resource.MustParse("200m"),
							corev1.ResourceMemory: resource.MustParse("128Mi"),
						},
					},
				},
			},
		},
	}
}

// podNameFor returns the deterministic Pod name for a given ComputeTask.
func podNameFor(ct *computev1alpha1.ComputeTask) string {
	return fmt.Sprintf("ct-%s", ct.Name)
}

// podPhaseToTaskPhase maps corev1.PodPhase to ComputeTaskPhase.
func podPhaseToTaskPhase(phase corev1.PodPhase) computev1alpha1.ComputeTaskPhase {
	switch phase {
	case corev1.PodRunning:
		return computev1alpha1.ComputeTaskPhaseRunning
	case corev1.PodSucceeded:
		return computev1alpha1.ComputeTaskPhaseSucceeded
	case corev1.PodFailed:
		return computev1alpha1.ComputeTaskPhaseFailed
	default:
		return computev1alpha1.ComputeTaskPhasePending
	}
}

// SetupWithManager registers the controller with the manager and sets up watches.
func (r *ComputeTaskReconciler) SetupWithManager(mgr ctrl.Manager) error {
	// Read cluster name from env — set by the Deployment manifest.
	if r.ClusterName == "" {
		r.ClusterName = os.Getenv("WORKER_CLUSTER_NAME")
	}

	return ctrl.NewControllerManagedBy(mgr).
		For(&computev1alpha1.ComputeTask{}).
		Owns(&corev1.Pod{}).
		Complete(r)
}

// DeepCopy is a convenience helper for status.
func (s *computev1alpha1.ComputeTaskStatus) DeepCopy() *computev1alpha1.ComputeTaskStatus {
	out := new(computev1alpha1.ComputeTaskStatus)
	s.DeepCopyInto(out)
	return out
}
