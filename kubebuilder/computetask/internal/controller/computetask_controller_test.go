/*
Copyright 2026.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package controller

import (
	"context"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/types"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"

	examplecomv1 "example.com/computetask/api/v1"
)

var _ = Describe("ComputeTask Controller", func() {
	Context("When reconciling a resource", func() {
		const resourceName = "test-resource"
		const testNamespace = "default"

		ctx := context.Background()

		typeNamespacedName := types.NamespacedName{
			Name:      resourceName,
			Namespace: testNamespace,
		}

		AfterEach(func() {
			// Clean up the ComputeTask if it exists.
			ct := &examplecomv1.ComputeTask{}
			err := k8sClient.Get(ctx, typeNamespacedName, ct)
			if err == nil {
				By("Cleaning up the ComputeTask")
				Expect(k8sClient.Delete(ctx, ct)).To(Succeed())
			}
			// Clean up any lingering Pod.
			pod := &corev1.Pod{}
			podKey := types.NamespacedName{Name: "ct-" + resourceName, Namespace: testNamespace}
			err = k8sClient.Get(ctx, podKey, pod)
			if err == nil {
				By("Cleaning up the backing Pod")
				Expect(k8sClient.Delete(ctx, pod)).To(Succeed())
			}
		})

		podTemplate := &corev1.PodTemplateSpec{
			Spec: corev1.PodSpec{
				RestartPolicy: corev1.RestartPolicyNever,
				Containers: []corev1.Container{
					{
						Name:    "task",
						Image:   "busybox:1.36",
						Command: []string{"sh", "-c", "echo hello"},
					},
				},
			},
		}

		It("should create a Pod when suspend is false", func() {
			By("Creating a ComputeTask with suspend=false")
			ct := &examplecomv1.ComputeTask{
				ObjectMeta: metav1.ObjectMeta{
					Name:      resourceName,
					Namespace: testNamespace,
				},
				Spec: examplecomv1.ComputeTaskSpec{
					Suspend:  false,
					Template: podTemplate,
				},
			}
			Expect(k8sClient.Create(ctx, ct)).To(Succeed())

			By("Reconciling the ComputeTask")
			r := &ComputeTaskReconciler{
				Client: k8sClient,
				Scheme: k8sClient.Scheme(),
			}
			_, err := r.Reconcile(ctx, reconcile.Request{NamespacedName: typeNamespacedName})
			Expect(err).NotTo(HaveOccurred())

			By("Verifying the backing Pod was created")
			pod := &corev1.Pod{}
			Eventually(func() error {
				return k8sClient.Get(ctx, types.NamespacedName{
					Name:      "ct-" + resourceName,
					Namespace: testNamespace,
				}, pod)
			}, 5*time.Second, time.Second).Should(Succeed())

			Expect(pod.Name).To(Equal("ct-" + resourceName))
			Expect(pod.Spec.Containers).To(HaveLen(1))
			Expect(pod.Spec.Containers[0].Name).To(Equal("task"))
			Expect(pod.Spec.Containers[0].Image).To(Equal("busybox:1.36"))
		})

		It("should delete the Pod and set Pending phase when suspend is true", func() {
			By("Creating a ComputeTask with suspend=false")
			ct := &examplecomv1.ComputeTask{
				ObjectMeta: metav1.ObjectMeta{
					Name:      resourceName,
					Namespace: testNamespace,
				},
				Spec: examplecomv1.ComputeTaskSpec{
					Suspend:  false,
					Template: podTemplate,
				},
			}
			Expect(k8sClient.Create(ctx, ct)).To(Succeed())

			r := &ComputeTaskReconciler{
				Client: k8sClient,
				Scheme: k8sClient.Scheme(),
			}

			By("Reconciling to create the Pod")
			_, err := r.Reconcile(ctx, reconcile.Request{NamespacedName: typeNamespacedName})
			Expect(err).NotTo(HaveOccurred())

			By("Verifying the Pod was created")
			pod := &corev1.Pod{}
			Eventually(func() error {
				return k8sClient.Get(ctx, types.NamespacedName{
					Name:      "ct-" + resourceName,
					Namespace: testNamespace,
				}, pod)
			}, 5*time.Second, time.Second).Should(Succeed())

			By("Suspending the ComputeTask")
			Expect(k8sClient.Get(ctx, typeNamespacedName, ct)).To(Succeed())
			ct.Spec.Suspend = true
			Expect(k8sClient.Update(ctx, ct)).To(Succeed())

			By("Reconciling with suspend=true")
			_, err = r.Reconcile(ctx, reconcile.Request{NamespacedName: typeNamespacedName})
			Expect(err).NotTo(HaveOccurred())

			By("Verifying the Pod was deleted")
			Eventually(func() bool {
				err := k8sClient.Get(ctx, types.NamespacedName{
					Name:      "ct-" + resourceName,
					Namespace: testNamespace,
				}, pod)
				return errors.IsNotFound(err)
			}, 10*time.Second, time.Second).Should(BeTrue())
		})

		It("should not create a Pod when ComputeTask does not exist", func() {
			By("Reconciling a non-existent ComputeTask")
			r := &ComputeTaskReconciler{
				Client: k8sClient,
				Scheme: k8sClient.Scheme(),
			}
			_, err := r.Reconcile(ctx, reconcile.Request{
				NamespacedName: types.NamespacedName{
					Name:      "non-existent",
					Namespace: testNamespace,
				},
			})
			Expect(err).NotTo(HaveOccurred())
		})
	})
})
