package server

import (
	"crypto/tls"
	"flag"
	"fmt"
	"net/http"
	"os"

	"github.com/patilchinmay/k8s-experiments/policy/kubewebhook/src/app"
	"github.com/sirupsen/logrus"
	kwhlogrus "github.com/slok/kubewebhook/v2/pkg/log/logrus"
)

const (
	port = "8080"
)

type config struct {
	certFile string
	keyFile  string
}

func initFlags() *config {
	cfg := &config{}

	fl := flag.NewFlagSet(os.Args[0], flag.ExitOnError)
	fl.StringVar(&cfg.certFile, "tls-cert-file", "/etc/certs/tls.crt", "TLS certificate file")
	fl.StringVar(&cfg.keyFile, "tls-key-file", "/etc/certs/tls.key", "TLS key file")

	_ = fl.Parse(os.Args[1:])
	return cfg
}

func Serve() {
	logrusLogEntry := logrus.NewEntry(logrus.New())
	logrusLogEntry.Logger.SetLevel(logrus.DebugLevel)
	logger := kwhlogrus.NewLogrus(logrusLogEntry)

	cfg := initFlags()

	mux, err := app.New(logger)
	if err != nil {
		logger.Errorf("Failed to initialize webhook server: %s", err)
		os.Exit(1)
	}

	server := &http.Server{
		Addr:    fmt.Sprintf(":%v", port),
		Handler: mux,
		TLSConfig: &tls.Config{
			GetCertificate: func(chi *tls.ClientHelloInfo) (*tls.Certificate, error) {
				certs, err := tls.LoadX509KeyPair(cfg.certFile, cfg.keyFile)
				if err != nil {
					return nil, fmt.Errorf("failed to load key pair: %w", err)
				}
				return &certs, nil
			},
		},
	}

	// Start the server
	logger.Infof("Starting server...")
	// log.Fatal(http.ListenAndServe("0.0.0.0:8989", app))
	if err := server.ListenAndServeTLS("", ""); err != nil {
		if err == http.ErrServerClosed {
			logger.Infof("Server closed")
		} else {
			logger.Errorf("Failed to listen, forcing exit: %s", err)
			os.Exit(1)
		}
	}
}
