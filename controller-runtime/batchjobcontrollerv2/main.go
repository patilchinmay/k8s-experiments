package main

import (
	"os"

	batchv1 "k8s.io/api/batch/v1"
	corev1 "k8s.io/api/core/v1"

	_ "k8s.io/client-go/plugin/pkg/client/auth/gcp"
	"sigs.k8s.io/controller-runtime/pkg/builder"
	"sigs.k8s.io/controller-runtime/pkg/client/config"
	"sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/controller-runtime/pkg/log/zap"
	"sigs.k8s.io/controller-runtime/pkg/manager"
	"sigs.k8s.io/controller-runtime/pkg/manager/signals"
)

func init() {
	log.SetLogger(zap.New())
}

func main() {
	entryLog := log.Log.WithName("entrypoint")

	// Setup a Manager
	entryLog.Info("setting up manager")
	mgr, err := manager.New(config.GetConfigOrDie(), manager.Options{})
	if err != nil {
		entryLog.Error(err, "unable to set up overall controller manager")
		os.Exit(1)
	}

	// Setup a new controller to reconcile Batch Jobs
	entryLog.Info("Setting up controller")
	if err := builder.ControllerManagedBy(mgr).
		For(&batchv1.Job{}). // batchv1.Job is the Application API
		Owns(&corev1.Pod{}). // batchv1.Job owns Pods created by it
		Complete(&reconcileBatchJob{client: mgr.GetClient()}); err != nil {
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
	if err := mgr.Start(signals.SetupSignalHandler()); err != nil {
		entryLog.Error(err, "unable to run manager")
		os.Exit(1)
	}
}
