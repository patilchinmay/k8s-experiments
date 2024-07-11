package main

import (
	"os"
	"time"

	_ "k8s.io/client-go/plugin/pkg/client/auth/gcp"
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

	// Create our Runnable with an interval
	entryLog.Info("Setting up Runnable")
	runnable := &MyRunnable{interval: 1 * time.Second}

	// Wrap the Runnable with manager.RunnableFunc for registration
	err = mgr.Add(manager.RunnableFunc(runnable.Start))
	if err != nil {
		entryLog.Error(err, "unable to add runnable to manager")
		return
	}

	// Start the manager which starts the runnables as well
	entryLog.Info("starting manager")
	if err := mgr.Start(signals.SetupSignalHandler()); err != nil {
		entryLog.Error(err, "unable to run manager")
		os.Exit(1)
	}
}
