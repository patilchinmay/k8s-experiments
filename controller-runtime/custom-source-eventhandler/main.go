package main

import (
	"context"
	"os"
	"time"

	"sigs.k8s.io/controller-runtime/pkg/client/config"
	"sigs.k8s.io/controller-runtime/pkg/controller"
	"sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/controller-runtime/pkg/log/zap"
	"sigs.k8s.io/controller-runtime/pkg/manager"
	"sigs.k8s.io/controller-runtime/pkg/manager/signals"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"
	"sigs.k8s.io/controller-runtime/pkg/source"
)

// Define constants
const (
	tickerInterval  time.Duration = 2 * time.Second
	timeoutInterval time.Duration = 7 * time.Second
)

func init() {
	log.SetLogger(zap.New(zap.UseDevMode(true)))
}

func main() {
	entryLog := log.Log.WithName("entrypoint")

	// Create a context with a timeout
	ctxTimeout, cancel := context.WithTimeout(signals.SetupSignalHandler(), timeoutInterval)
	defer cancel()

	// Create a Manager
	entryLog.Info("setting up manager")
	mgr, err := manager.New(config.GetConfigOrDie(), manager.Options{})
	if err != nil {
		entryLog.Error(err, "unable to set up overall controller manager")
		os.Exit(1)
	}

	// Create a Controller that is registered with the manager
	c, err := controller.New("batchjob-controller", mgr, controller.Options{
		Reconciler: reconcile.Func(func(ctx context.Context, req reconcile.Request) (reconcile.Result, error) {
			log := log.FromContext(ctx) // Get the logger from the context
			log.Info("reconciler", "incoming req", req.NamespacedName)

			// Your business logic to implement the API by creating, updating, deleting objects goes here.
			return reconcile.Result{}, nil
		}),
	})
	if err != nil {
		entryLog.Error(err, "unable to create batchjob-controller")
		os.Exit(1)
	}

	// Create External Event Handler
	eeh := NewExternalEventHandler(log.Log.WithName("handler"))

	// Create External Event Source
	ees := NewExternalEventSource(log.Log.WithName("source"))

	// Create channel that will receive the external events
	eventsCh := ees.Fetch(ctxTimeout)

	// Create Source and setup controller to Watch it
	entryLog.Info("setting up source and watch")
	err = c.Watch(
		source.Channel(eventsCh, eeh),
	)
	if err != nil {
		entryLog.Error(err, "unable to watch pods")
		os.Exit(1)
	}

	// Start the manager which starts the controller as well
	entryLog.Info("starting manager")
	if err := mgr.Start(ctxTimeout); err != nil {
		entryLog.Error(err, "unable to run manager")
		os.Exit(1)
	}

}
