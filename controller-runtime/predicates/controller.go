package main

import (
	"context"
	"fmt"

	batchv1 "k8s.io/api/batch/v1"
	corev1 "k8s.io/api/core/v1"

	"k8s.io/apimachinery/pkg/api/errors"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"
)

// reconcileBatchJob reconciles BatchJobs
type reconcileBatchJob struct {
	// client can be used to retrieve objects from the APIServer.
	client client.Client
}

// Implement reconcile.Reconciler so the controller can reconcile objects
var _ reconcile.Reconciler = &reconcileBatchJob{}

// Implement the business logic:
// This function will be called when there is a change to a batchv1.Job or a Pod with an OwnerReference
// to a batchv1.Job.
//
// * Read the batchv1.Job
// * Read the Pods
// * Print to terminal
func (r *reconcileBatchJob) Reconcile(ctx context.Context, request reconcile.Request) (reconcile.Result, error) {
	// set up a convenient log object so we don't have to type request over and over again
	log := log.FromContext(ctx) // Get the logger from the context

	// Fetch the batchv1.Job from the cache
	job := &batchv1.Job{}
	err := r.client.Get(ctx, request.NamespacedName, job)
	if errors.IsNotFound(err) {
		log.Error(nil, "Could not find BatchJob")
		return reconcile.Result{}, nil
	}

	if err != nil {
		return reconcile.Result{}, fmt.Errorf("could not fetch BatchJob: %+v", err)
	}

	// Print the BatchJob
	log.Info("Reconciling batchv1.Job", "container name", job.Spec.Template.Spec.Containers[0].Name)

	// Fetch Pods (owned by batchv1.Job) from the cache
	pods := &corev1.PodList{}
	err = r.client.List(ctx, pods, client.InNamespace(request.Namespace), client.MatchingLabels(job.Spec.Template.Labels))
	if err != nil {
		return reconcile.Result{}, err
	}

	// Update label
	job.Labels["pod-count"] = fmt.Sprintf("%v", len(pods.Items))
	err = r.client.Update(context.TODO(), job)
	if err != nil {
		return reconcile.Result{}, fmt.Errorf("could not write BatchJob: %+v", err)
	}

	log.Info("Reconcile successful", "name", request.Name)
	return reconcile.Result{}, nil
}
