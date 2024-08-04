package main

import (
	"os"

	batchv1 "k8s.io/api/batch/v1"
	corev1 "k8s.io/api/core/v1"

	_ "k8s.io/client-go/plugin/pkg/client/auth/gcp"
	"sigs.k8s.io/controller-runtime/pkg/builder"
	"sigs.k8s.io/controller-runtime/pkg/client/config"
	"sigs.k8s.io/controller-runtime/pkg/event"
	"sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/controller-runtime/pkg/log/zap"
	mgr "sigs.k8s.io/controller-runtime/pkg/manager"
	"sigs.k8s.io/controller-runtime/pkg/manager/signals"
	"sigs.k8s.io/controller-runtime/pkg/predicate"
)

func init() {
	log.SetLogger(zap.New())
}

func main() {
	entryLog := log.Log.WithName("entrypoint")

	// Setup a Manager
	entryLog.Info("setting up manager")
	manager, err := mgr.New(config.GetConfigOrDie(), mgr.Options{})
	if err != nil {
		entryLog.Error(err, "unable to set up overall controller manager")
		os.Exit(1)
	}

	// Setup a new controller to reconcile Batch Jobs
	entryLog.Info("Setting up controller")
	if err := builder.ControllerManagedBy(manager).
		For(&batchv1.Job{}). // batchv1.Job is the Application API
		Owns(&corev1.Pod{}). // trigger the Reconcile whenever an Owned pod is created/updated/deleted
		WithEventFilter(predicate.Funcs{
			UpdateFunc: func(e event.UpdateEvent) bool {
				return false
			},
			DeleteFunc: func(e event.DeleteEvent) bool {
				return false
			},
			// Only handle (watch for) create events
			CreateFunc: func(e event.CreateEvent) bool {
				entryLog.Info("Create event received for", "job or pod", e.Object)
				return true
			},
			GenericFunc: func(e event.GenericEvent) bool {
				return false
			},
		}).
		Complete(&reconcileBatchJob{client: manager.GetClient()}); err != nil {
		entryLog.Error(err, "could not create controller")
		os.Exit(1)
	}

	// Set up webhooks
	// if err := builder.WebhookManagedBy(mgr).
	// 	For(&corev1.Pod{}).
	// 	WithDefaulter(&podAnnotator{}).
	// 	WithValidator(&podValidator{}).
	// 	Complete(); err != nil {
	// 	entryLog.Error(err, "unable to create webhook", "webhook", "Pod")
	// 	os.Exit(1)
	// }

	entryLog.Info("starting manager")
	if err := manager.Start(signals.SetupSignalHandler()); err != nil {
		entryLog.Error(err, "unable to run manager")
		os.Exit(1)
	}
}
