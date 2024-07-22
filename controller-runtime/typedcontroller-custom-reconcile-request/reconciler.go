package main

import (
	"context"

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
var (
	_ reconcile.TypedReconciler[CustomReconcileRequest] = &reconcileBatchJob{}
)

// Implement the business logic:
// This function will be called when there is a change to a batchv1.Job or a Pod with an OwnerReference
// to a batchv1.Job.
//
// * Read the batchv1.Job
// * Read the Pods
// * Print to terminal
func (r *reconcileBatchJob) Reconcile(ctx context.Context, req CustomReconcileRequest) (reconcile.Result, error) {
	// set up a convenient log object so we don't have to type request over and over again
	log := log.FromContext(ctx) // Get the logger from the context

	// Print the request
	log.Info("reconciler", "incoming req", req, "userID", req.userID)

	return reconcile.Result{}, nil
}
