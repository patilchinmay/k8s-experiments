package main

import (
	"flag"
	"os"
	"os/signal"
	"path/filepath"
	"time"

	"github.com/sirupsen/logrus"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime/schema"
	"k8s.io/apimachinery/pkg/util/runtime"
	"k8s.io/client-go/dynamic"
	"k8s.io/client-go/dynamic/dynamicinformer"
	"k8s.io/client-go/tools/cache"
	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/util/homedir"
	"k8s.io/klog"
)

// https://macias.info/entry/202109081800_k8s_informers.md
// https://blog.dsb.dev/posts/creating-dynamic-informers/

// use informers in Kubernetes for particular resources, but what if you need to be able to receive events for any Kubernetes resource dynamically? The answer is dynamicinformer.

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

	// Grab a dynamic interface that we can create informers from
	dynamicClient, err := dynamic.NewForConfig(config)
	if err != nil {
		logrus.WithError(err).Fatal("could not generate dynamic client for config")
	}

	// Create a factory object that we can say "hey, I need to watch this resource"
	// and it will give us back an informer for it
	factory := dynamicinformer.NewFilteredDynamicSharedInformerFactory(dynamicClient, time.Minute, corev1.NamespaceAll, nil)

	// Retrieve a "GroupVersionResource" type that we need when generating our informer from our dynamic factory
	resource := schema.GroupVersionResource{Group: "", Version: "v1", Resource: "pods"}

	// Finally, create our informer for deployments!
	informer := factory.ForResource(resource).Informer()

	// Add event handlers
	informer.AddEventHandler(cache.ResourceEventHandlerFuncs{
		AddFunc: func(obj interface{}) {
			pod := obj.(*unstructured.Unstructured)
			klog.Infof("POD CREATED: %s/%s\n", pod.GetNamespace(), pod.GetName())
		},
		UpdateFunc: func(oldObj, newObj interface{}) {
			oldPod := oldObj.(*unstructured.Unstructured)
			newPod := newObj.(*unstructured.Unstructured)
			klog.Infof(
				"POD UPDATED. %s/%s %s\n",
				oldPod.GetNamespace(), oldPod.GetName(), newPod.GetName(),
			)
		},
		DeleteFunc: func(obj interface{}) {
			pod := obj.(*unstructured.Unstructured)
			klog.Infof("POD DELETED: %s/%s", pod.GetNamespace(), pod.GetName())
		},
	})

	stopper := make(chan struct{})
	defer close(stopper)
	defer runtime.HandleCrash()

	go informer.Run(stopper)

	sigCh := make(chan os.Signal)
	signal.Notify(sigCh, os.Kill, os.Interrupt)

	<-sigCh
}
