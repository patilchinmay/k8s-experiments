/*
Copyright 2026.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

// Package controller implements the ComputeTask controller.
//
// Reconcile loop:
//  1. Fetch the ComputeTask.
//  2. If spec.suspend == true → ensure any existing Pod is deleted; set status.phase=Pending.
//  3. If spec.suspend == false and no Pod exists → create a Pod from spec.template.
//  4. Watch Pod phase and propagate it back into ComputeTask.status.
package controller

import (
	"context"
	"fmt"
	"maps"

	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"
	"sigs.k8s.io/controller-runtime/pkg/log"

	examplecomv1 "example.com/computetask/api/v1"
)

// ComputeTaskReconciler reconciles a ComputeTask object.
type ComputeTaskReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

// +kubebuilder:rbac:groups=example.com,resources=computetasks,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=example.com,resources=computetasks/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=example.com,resources=computetasks/finalizers,verbs=update
// +kubebuilder:rbac:groups="",resources=pods,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=events.k8s.io,resources=events,verbs=create;patch

// Reconcile implements the main reconcile loop for ComputeTask.
func (r *ComputeTaskReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx)

	// 1. Fetch the ComputeTask.
	ct := &examplecomv1.ComputeTask{}
	if err := r.Get(ctx, req.NamespacedName, ct); err != nil {
		if apierrors.IsNotFound(err) {
			return ctrl.Result{}, nil
		}
		return ctrl.Result{}, fmt.Errorf("get ComputeTask: %w", err)
	}

	// 2. If suspended, delete any existing Pod and set status to Pending.
	if ct.Spec.Suspend {
		if err := r.deletePodIfExists(ctx, ct); err != nil {
			return ctrl.Result{}, err
		}
		return r.updateStatus(ctx, ct, func(s *examplecomv1.ComputeTaskStatus) {
			s.Phase = examplecomv1.ComputeTaskPhasePending
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
		logger.Info("Creating Pod for ComputeTask", "pod", podName)
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
	return r.updateStatus(ctx, ct, func(s *examplecomv1.ComputeTaskStatus) {
		s.Phase = desiredPhase
		s.PodName = podName
		if pod.Status.StartTime != nil && s.StartTime == nil {
			s.StartTime = pod.Status.StartTime
		}
		if (desiredPhase == examplecomv1.ComputeTaskPhaseSucceeded ||
			desiredPhase == examplecomv1.ComputeTaskPhaseFailed) &&
			s.CompletionTime == nil {
			now := metav1.Now()
			s.CompletionTime = &now
		}
	})
}

// updateStatus patches ComputeTask.status only if it has changed.
func (r *ComputeTaskReconciler) updateStatus(
	ctx context.Context,
	ct *examplecomv1.ComputeTask,
	mutate func(*examplecomv1.ComputeTaskStatus),
) (ctrl.Result, error) {
	patch := client.MergeFrom(ct.DeepCopy())
	mutate(&ct.Status)
	if err := r.Status().Patch(ctx, ct, patch); err != nil {
		return ctrl.Result{}, fmt.Errorf("update ComputeTask status: %w", err)
	}
	return ctrl.Result{}, nil
}

// deletePodIfExists deletes the backing Pod if it exists.
func (r *ComputeTaskReconciler) deletePodIfExists(ctx context.Context, ct *examplecomv1.ComputeTask) error {
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

// buildPod constructs the Pod from the ComputeTask's spec.template.
func (r *ComputeTaskReconciler) buildPod(ct *examplecomv1.ComputeTask) *corev1.Pod {
	podName := podNameFor(ct)
	tmpl := ct.Spec.Template

	// Merge labels: template labels take precedence; always include the tracking label.
	labels := make(map[string]string, len(tmpl.Labels)+1)
	maps.Copy(labels, tmpl.Labels)
	labels["example.com/computetask"] = ct.Name

	return &corev1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			Name:        podName,
			Namespace:   ct.Namespace,
			Labels:      labels,
			Annotations: tmpl.Annotations,
		},
		Spec: tmpl.Spec,
	}
}

// podNameFor returns the deterministic Pod name for a given ComputeTask.
func podNameFor(ct *examplecomv1.ComputeTask) string {
	return fmt.Sprintf("ct-%s", ct.Name)
}

// podPhaseToTaskPhase maps corev1.PodPhase to ComputeTaskPhase.
func podPhaseToTaskPhase(phase corev1.PodPhase) examplecomv1.ComputeTaskPhase {
	switch phase {
	case corev1.PodRunning:
		return examplecomv1.ComputeTaskPhaseRunning
	case corev1.PodSucceeded:
		return examplecomv1.ComputeTaskPhaseSucceeded
	case corev1.PodFailed:
		return examplecomv1.ComputeTaskPhaseFailed
	default:
		return examplecomv1.ComputeTaskPhasePending
	}
}

// SetupWithManager registers the controller with the manager and sets up watches.
func (r *ComputeTaskReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&examplecomv1.ComputeTask{}).
		Owns(&corev1.Pod{}).
		Named("computetask").
		Complete(r)
}
