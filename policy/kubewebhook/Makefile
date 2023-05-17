.PHONY: run
run:
	go run main.go --tls-cert-file certs/server.crt --tls-key-file certs/server.key

.PHONY: build
build:
	docker build -t patilchinmay/kubewebhook:0.0.1 -f Dockerfile .

.PHONY: load
load:
	kind load docker-image patilchinmay/kubewebhook:0.0.1 --name kind

