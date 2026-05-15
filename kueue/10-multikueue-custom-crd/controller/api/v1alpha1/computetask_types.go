// Package v1alpha1 contains API Schema definitions for the compute.example.com v1alpha1 API group.
// +groupName=compute.example.com
package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/schema"
	"sigs.k8s.io/controller-runtime/pkg/scheme"
)

// GroupVersion is the group version used to register these objects.
var GroupVersion = schema.GroupVersion{Group: "compute.example.com", Version: "v1alpha1"}

// SchemeBuilder is used to add go types to the GroupVersionKind scheme.
var SchemeBuilder = &scheme.Builder{GroupVersion: GroupVersion}

// AddToScheme adds the types in this group-version to the given scheme.
var AddToScheme = SchemeBuilder.AddToScheme

// ComputeTaskPhase represents the phase of a ComputeTask.
type ComputeTaskPhase string

const (
	// ComputeTaskPhasePending means the task has been accepted but the Pod has not started yet.
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
	// DurationSeconds is how many seconds the compute task should run before completing.
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:default=60
	DurationSeconds int32 `json:"durationSeconds,omitempty"`

	// Suspend, when true, prevents the controller from creating the backing Pod.
	// Kueue sets this to true on admission hold and clears it once the workload is admitted.
	// +kubebuilder:default=true
	Suspend bool `json:"suspend"`
}

// ComputeTaskStatus defines the observed state of ComputeTask.
type ComputeTaskStatus struct {
	// Phase is the current lifecycle phase of the task.
	// +kubebuilder:validation:Enum=Pending;Running;Succeeded;Failed
	Phase ComputeTaskPhase `json:"phase,omitempty"`

	// StartTime is when the backing Pod started running.
	// +optional
	StartTime *metav1.Time `json:"startTime,omitempty"`

	// CompletionTime is when the backing Pod finished (succeeded or failed).
	// +optional
	CompletionTime *metav1.Time `json:"completionTime,omitempty"`

	// WorkerCluster is the name of the cluster where the Pod is running.
	// The worker controller sets this; MultiKueue propagates it back to the manager.
	// +optional
	WorkerCluster string `json:"workerCluster,omitempty"`

	// PodName is the name of the Pod created by the worker controller.
	// +optional
	PodName string `json:"podName,omitempty"`

	// Conditions holds standard Kubernetes conditions for the task.
	// +optional
	// +listType=map
	// +listMapKey=type
	Conditions []metav1.Condition `json:"conditions,omitempty"`
}

// ComputeTask is the Schema for the computetasks API.
//
// A ComputeTask represents a unit of compute work. When submitted to the manager
// cluster with a kueue.x-k8s.io/queue-name label, Kueue admits it and (via
// MultiKueue) dispatches it to a worker cluster. The worker controller then
// creates a Pod that sleeps for spec.durationSeconds and reports status back.
//
// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:resource:shortName=ct,categories=all
// +kubebuilder:printcolumn:name="Phase",type=string,JSONPath=`.status.phase`
// +kubebuilder:printcolumn:name="Worker",type=string,JSONPath=`.status.workerCluster`
// +kubebuilder:printcolumn:name="Age",type=date,JSONPath=`.metadata.creationTimestamp`
type ComputeTask struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   ComputeTaskSpec   `json:"spec,omitempty"`
	Status ComputeTaskStatus `json:"status,omitempty"`
}

// ComputeTaskList contains a list of ComputeTask.
// +kubebuilder:object:root=true
type ComputeTaskList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []ComputeTask `json:"items"`
}

func init() {
	SchemeBuilder.Register(&ComputeTask{}, &ComputeTaskList{})
}

// GetCondition returns the condition with the given type, or nil.
func (ct *ComputeTask) GetCondition(condType string) *metav1.Condition {
	for i := range ct.Status.Conditions {
		if ct.Status.Conditions[i].Type == condType {
			return &ct.Status.Conditions[i]
		}
	}
	return nil
}

// DeepCopyObject implements runtime.Object.
func (ct *ComputeTask) DeepCopyObject() runtime.Object {
	if c := ct.DeepCopy(); c != nil {
		return c
	}
	return nil
}

// DeepCopy creates a deep copy of ComputeTask.
func (ct *ComputeTask) DeepCopy() *ComputeTask {
	if ct == nil {
		return nil
	}
	out := new(ComputeTask)
	ct.DeepCopyInto(out)
	return out
}

// DeepCopyInto copies all fields of ct into out.
func (ct *ComputeTask) DeepCopyInto(out *ComputeTask) {
	*out = *ct
	out.TypeMeta = ct.TypeMeta
	ct.ObjectMeta.DeepCopyInto(&out.ObjectMeta)
	out.Spec = ct.Spec
	ct.Status.DeepCopyInto(&out.Status)
}

// DeepCopyInto copies all fields of the status into out.
func (s *ComputeTaskStatus) DeepCopyInto(out *ComputeTaskStatus) {
	*out = *s
	if s.StartTime != nil {
		t := *s.StartTime
		out.StartTime = &t
	}
	if s.CompletionTime != nil {
		t := *s.CompletionTime
		out.CompletionTime = &t
	}
	if s.Conditions != nil {
		out.Conditions = make([]metav1.Condition, len(s.Conditions))
		copy(out.Conditions, s.Conditions)
	}
}

// DeepCopyObject implements runtime.Object for ComputeTaskList.
func (l *ComputeTaskList) DeepCopyObject() runtime.Object {
	if c := l.DeepCopy(); c != nil {
		return c
	}
	return nil
}

// DeepCopy creates a deep copy of ComputeTaskList.
func (l *ComputeTaskList) DeepCopy() *ComputeTaskList {
	if l == nil {
		return nil
	}
	out := new(ComputeTaskList)
	l.DeepCopyInto(out)
	return out
}

// DeepCopyInto copies all fields of the list into out.
func (l *ComputeTaskList) DeepCopyInto(out *ComputeTaskList) {
	*out = *l
	out.TypeMeta = l.TypeMeta
	l.ListMeta.DeepCopyInto(&out.ListMeta)
	if l.Items != nil {
		out.Items = make([]ComputeTask, len(l.Items))
		for i := range l.Items {
			l.Items[i].DeepCopyInto(&out.Items[i])
		}
	}
}
