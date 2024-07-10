package main

import (
	"context"
	"fmt"
	"os"

	batchv1 "k8s.io/api/batch/v1"
	corev1 "k8s.io/api/core/v1"
	ctrl "sigs.k8s.io/controller-runtime"

	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/controller-runtime/pkg/log/zap"

	// since we invoke tests with -ginkgo.junit-report we need to import ginkgo.
	_ "github.com/onsi/ginkgo/v2"
)

func init() {
	log.SetLogger(zap.New())
}

func main() {
	var log = ctrl.Log.WithName("batchjobcontroller")

	manager, err := ctrl.NewManager(ctrl.GetConfigOrDie(), ctrl.Options{})
	if err != nil {
		log.Error(err, "could not create manager")
		os.Exit(1)
	}

	err = ctrl.
		NewControllerManagedBy(manager). // Create the Controller
		For(&batchv1.Job{}).             // batchv1.Job is the Application API
		Owns(&corev1.Pod{}).             // batchv1.Job owns Pods created by it
		Complete(&BatchJobReconciler{Client: manager.GetClient()})
	if err != nil {
		log.Error(err, "could not create controller")
		os.Exit(1)
	}

	if err := manager.Start(ctrl.SetupSignalHandler()); err != nil {
		log.Error(err, "could not start manager")
		os.Exit(1)
	}
}

// BatchJobReconciler is a simple Controller example implementation.
type BatchJobReconciler struct {
	client.Client
}

// Implement the business logic:
// This function will be called when there is a change to a batchv1.Job or a Pod with an OwnerReference
// to a batchv1.Job.
//
// * Read the batchv1.Job
// * Read the Pods
// * Print to terminal
func (a *BatchJobReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	log := log.FromContext(ctx) // Get the logger from the context
	log.Info("Reconciling batchv1.Job", "name", req.Name)

	job := &batchv1.Job{}
	err := a.Get(ctx, req.NamespacedName, job)
	if err != nil {
		return ctrl.Result{}, err
	}

	pods := &corev1.PodList{}
	err = a.List(ctx, pods, client.InNamespace(req.Namespace), client.MatchingLabels(job.Spec.Template.Labels))
	if err != nil {
		return ctrl.Result{}, err
	}

	job.Labels["pod-count"] = fmt.Sprintf("%v", len(pods.Items))
	err = a.Update(context.TODO(), job)
	if err != nil {
		return ctrl.Result{}, err
	}

	log.Info("Reconcile successful", "name", req.Name)
	return ctrl.Result{}, nil
}
