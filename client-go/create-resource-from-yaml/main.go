package main

import (
	"context"
	_ "embed"
	"flag"
	"fmt"
	"path/filepath"

	batchv1 "k8s.io/api/batch/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/kubernetes/scheme"
	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/util/homedir"
)

//go:embed job.yaml
var jobYaml []byte

func main() {
	var kubeconfig *string
	if home := homedir.HomeDir(); home != "" {
		kubeconfig = flag.String("kubeconfig", filepath.Join(home, ".kube", "config"), "(optional) absolute path to the kubeconfig file")
	} else {
		kubeconfig = flag.String("kubeconfig", "", "absolute path to the kubeconfig file")
	}
	flag.Parse()

	// use the current context in kubeconfig
	config, err := clientcmd.BuildConfigFromFlags("", *kubeconfig)
	if err != nil {
		panic(err.Error())
	}

	// create the clientset
	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		panic(err.Error())
	}

	// k8s.io/client-go that's pre-loaded with the schemas
	// for all the standard Kubernetes resource types.
	decoder := scheme.Codecs.UniversalDeserializer()

	job := batchv1.Job{}
	_, detectedGroupVersionKind, err := decoder.Decode(
		jobYaml,
		nil,
		&job,
	)
	if err != nil {
		panic(err)
	}

	// Create the Job
	createdJob, err := clientset.BatchV1().Jobs("default").Create(context.TODO(), &job, metav1.CreateOptions{})
	if err != nil {
		panic(err)
	}

	fmt.Print("detectedGroupVersionKind = %+v\n", detectedGroupVersionKind)
	fmt.Printf("createdJob = %+v\n", createdJob)
}
