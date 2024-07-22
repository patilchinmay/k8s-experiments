package main

import (
	"os"

	batchv1 "k8s.io/api/batch/v1"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/builder"
	"sigs.k8s.io/controller-runtime/pkg/client/config"
	"sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/controller-runtime/pkg/log/zap"
	"sigs.k8s.io/controller-runtime/pkg/manager"
	"sigs.k8s.io/controller-runtime/pkg/source"
)

func init() {
	log.SetLogger(zap.New(zap.UseDevMode(true)))
}

func main() {
	entryLog := log.Log.WithName("entrypoint")

	// Create a Manager
	entryLog.Info("setting up manager")
	mgr, err := manager.New(config.GetConfigOrDie(), manager.Options{})
	if err != nil {
		entryLog.Error(err, "unable to set up overall controller manager")
		os.Exit(1)
	}

	// Create Typed Builder
	builder.TypedControllerManagedBy[CustomReconcileRequest](mgr).
		Named("typed_controller").
		WatchesRawSource(
			source.TypedKind(
				mgr.GetCache(),
				&batchv1.Job{},
				NewCustomEventHandler(log.Log.WithName("handler")),
			),
		).
		Build(&reconcileBatchJob{})

	// Start the manager which starts the controller as well
	entryLog.Info("starting manager")
	if err := mgr.Start(ctrl.SetupSignalHandler()); err != nil {
		entryLog.Error(err, "unable to run manager")
		os.Exit(1)
	}
}
