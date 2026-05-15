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

package v1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// ComputeTaskPhase represents the lifecycle phase of a ComputeTask.
// +kubebuilder:validation:Enum=Pending;Running;Succeeded;Failed
type ComputeTaskPhase string

const (
	// ComputeTaskPhasePending means the task has been accepted but the backing Pod has not started yet.
	ComputeTaskPhasePending ComputeTaskPhase = "Pending"
	// ComputeTaskPhaseRunning means the Pod backing this task is running.
	ComputeTaskPhaseRunning ComputeTaskPhase = "Running"
	// ComputeTaskPhaseSucceeded means the Pod completed successfully.
	ComputeTaskPhaseSucceeded ComputeTaskPhase = "Succeeded"
	// ComputeTaskPhaseFailed means the Pod failed.
	ComputeTaskPhaseFailed ComputeTaskPhase = "Failed"
)

// ComputeTaskSpec defines the desired state of ComputeTask.
type ComputeTaskSpec struct {
	// durationSeconds is how many seconds the compute task should run before completing.
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:default=60
	// +optional
	DurationSeconds int32 `json:"durationSeconds,omitempty"`

	// suspend, when true, prevents the controller from creating the backing Pod.
	// Set this to false to start the task.
	// +kubebuilder:default=false
	// +optional
	Suspend bool `json:"suspend,omitempty"`
}

// ComputeTaskStatus defines the observed state of ComputeTask.
type ComputeTaskStatus struct {
	// phase is the current lifecycle phase of the task.
	// +optional
	Phase ComputeTaskPhase `json:"phase,omitempty"`

	// startTime is when the backing Pod started running.
	// +optional
	StartTime *metav1.Time `json:"startTime,omitempty"`

	// completionTime is when the backing Pod finished (succeeded or failed).
	// +optional
	CompletionTime *metav1.Time `json:"completionTime,omitempty"`

	// podName is the name of the Pod created by the controller.
	// +optional
	PodName string `json:"podName,omitempty"`

	// conditions represent the current state of the ComputeTask resource.
	// +listType=map
	// +listMapKey=type
	// +optional
	Conditions []metav1.Condition `json:"conditions,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:resource:shortName=ct,categories=all
// +kubebuilder:printcolumn:name="Phase",type=string,JSONPath=`.status.phase`
// +kubebuilder:printcolumn:name="Pod",type=string,JSONPath=`.status.podName`
// +kubebuilder:printcolumn:name="Age",type=date,JSONPath=`.metadata.creationTimestamp`

// ComputeTask is the Schema for the computetasks API.
//
// A ComputeTask represents a unit of compute work. When spec.suspend is false,
// the controller creates a Pod that runs for spec.durationSeconds and then exits.
// The controller watches the Pod phase and propagates it back into status.phase.
type ComputeTask struct {
	metav1.TypeMeta `json:",inline"`

	// metadata is standard object metadata.
	// +optional
	metav1.ObjectMeta `json:"metadata,omitempty"`

	// spec defines the desired state of ComputeTask.
	// +optional
	Spec ComputeTaskSpec `json:"spec,omitempty"`

	// status defines the observed state of ComputeTask.
	// +optional
	Status ComputeTaskStatus `json:"status,omitempty"`
}

// +kubebuilder:object:root=true

// ComputeTaskList contains a list of ComputeTask.
type ComputeTaskList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []ComputeTask `json:"items"`
}

func init() {
	SchemeBuilder.Register(&ComputeTask{}, &ComputeTaskList{})
}
