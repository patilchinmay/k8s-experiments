package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"path/filepath"
	"time"

	batchv1 "k8s.io/api/batch/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/util/homedir"
	jobsetclientset "sigs.k8s.io/jobset/client-go/clientset/versioned"

	kubeflowv1 "github.com/kubeflow/training-operator/pkg/apis/kubeflow.org/v1"
	trainingoperatorclient "github.com/kubeflow/training-operator/pkg/client/clientset/versioned"
)

// ContainerInfo represents container information
type ContainerInfo struct {
	Name  string                `json:"name"`
	State corev1.ContainerState `json:"state"`
}

// PodInfo represents pod information
type PodInfo struct {
	Name              string               `json:"name"`
	Phase             corev1.PodPhase      `json:"phase"`
	InitContainers    []ContainerInfo      `json:"initContainers,omitempty"`
	Containers        []ContainerInfo      `json:"containers"`
	SidecarContainers []ContainerInfo      `json:"sidecarContainers,omitempty"`
	LastCondition     *corev1.PodCondition `json:"lastCondition,omitempty"`
}

// JobInfo represents job information with associated pods
type JobInfo struct {
	Name           string                `json:"name"`
	Status         string                `json:"status"`
	StartTime      *metav1.Time          `json:"startTime,omitempty"`
	CompletionTime *metav1.Time          `json:"completionTime,omitempty"`
	LastCondition  *batchv1.JobCondition `json:"lastCondition,omitempty"`
	Pods           []PodInfo             `json:"pods"`
}

// JobSetInfo represents jobset information with associated jobs
type JobSetInfo struct {
	Name          string            `json:"name"`
	Status        map[string]int    `json:"status"`
	Restarts      int32             `json:"restarts"`
	LastCondition *metav1.Condition `json:"lastCondition,omitempty"`
	Jobs          []JobInfo         `json:"jobs"`
}

// PyTorchJobInfo represents PyTorchJob information with associated pods
type PyTorchJobInfo struct {
	Name          string                   `json:"name"`
	Status        map[string]int           `json:"status"`
	LastCondition *kubeflowv1.JobCondition `json:"lastCondition,omitempty"`
	Pods          []PodInfo                `json:"pods"`
}

// Output represents the top-level JSON output structure
type Output struct {
	JobSet     *JobSetInfo     `json:"jobset,omitempty"`
	PyTorchJob *PyTorchJobInfo `json:"pytorchJob,omitempty"`
}

// https://github.com/kubernetes/client-go/blob/master/examples/out-of-cluster-client-configuration/main.go
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

	// setup clients
	clientset, jobsetClient, trainingClient, err := setupClients(config)
	if err != nil {
		panic(err.Error())
	}

	namespace := "default"
	jobsetName := "bash-counter-jobset"
	pytorchJobName := "pytorch-simple"

	// Print initial state
	fmt.Println("=== Initial State ===")
	printJobSetJSON(clientset, jobsetClient, namespace, jobsetName)
	printPyTorchJobJSON(clientset, trainingClient, namespace, pytorchJobName)

	// Create ticker to print every 30 seconds
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	fmt.Println("Printing job information every 30 seconds...")

	// Print on each tick
	for range ticker.C {
		fmt.Printf("=== Update at %s ===\n", time.Now().Format(time.RFC3339))
		printJobSetJSON(clientset, jobsetClient, namespace, jobsetName)
		printPyTorchJobJSON(clientset, trainingClient, namespace, pytorchJobName)
	}
}

// setupClients creates and returns the kubernetes, jobset, and training-operator clients
func setupClients(config *rest.Config) (*kubernetes.Clientset, *jobsetclientset.Clientset, *trainingoperatorclient.Clientset, error) {
	// create the kubernetes clientset
	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		return nil, nil, nil, err
	}

	// create the jobset clientset
	jobsetClient, err := jobsetclientset.NewForConfig(config)
	if err != nil {
		return nil, nil, nil, err
	}

	// create the training-operator clientset
	trainingClient, err := trainingoperatorclient.NewForConfig(config)
	if err != nil {
		return nil, nil, nil, err
	}

	return clientset, jobsetClient, trainingClient, nil
}

// printJobSetJSON fetches and prints jobset information as JSON
func printJobSetJSON(clientset *kubernetes.Clientset, jobsetClient *jobsetclientset.Clientset, namespace, jobsetName string) {
	jobsetInfo, err := getJobSetInfo(clientset, jobsetClient, namespace, jobsetName)
	if err != nil {
		fmt.Printf("Error getting jobset info: %v\n", err)
		return
	}

	output := Output{
		JobSet: jobsetInfo,
	}

	jsonOutput, err := json.MarshalIndent(output, "", "  ")
	if err != nil {
		fmt.Printf("Error marshaling JSON: %v\n", err)
		return
	}

	fmt.Println(string(jsonOutput))
	fmt.Println() // Add blank line for readability between outputs
}

// printPyTorchJobJSON fetches and prints PyTorchJob information as JSON
func printPyTorchJobJSON(clientset *kubernetes.Clientset, trainingClient *trainingoperatorclient.Clientset, namespace, pytorchJobName string) {
	pytorchJobInfo, err := getPyTorchJobInfo(clientset, trainingClient, namespace, pytorchJobName)
	if err != nil {
		fmt.Printf("Error getting PyTorchJob info: %v\n", err)
		return
	}

	output := Output{
		PyTorchJob: pytorchJobInfo,
	}

	jsonOutput, err := json.MarshalIndent(output, "", "  ")
	if err != nil {
		fmt.Printf("Error marshaling JSON: %v\n", err)
		return
	}

	fmt.Println(string(jsonOutput))
	fmt.Println() // Add blank line for readability between outputs
}

// ============================================================================
// PyTorchJob Status Functionality
// ============================================================================

// getPyTorchJobInfo extracts PyTorchJob and associated pod information
func getPyTorchJobInfo(clientset *kubernetes.Clientset, trainingClient *trainingoperatorclient.Clientset, namespace, pytorchJobName string) (*PyTorchJobInfo, error) {
	// Get the specific PyTorchJob
	pytorchJob, err := trainingClient.KubeflowV1().PyTorchJobs(namespace).Get(context.TODO(), pytorchJobName, metav1.GetOptions{})
	if err != nil {
		return nil, err
	}

	// Get pods for this PyTorchJob using label selector
	labelSelector := fmt.Sprintf("training.kubeflow.org/job-name=%s", pytorchJobName)
	pods, err := clientset.CoreV1().Pods(namespace).List(context.TODO(), metav1.ListOptions{
		LabelSelector: labelSelector,
	})
	if err != nil {
		return nil, err
	}

	// Get pod information
	podsInfo := getPodInfo(pods)

	// Get last condition if available
	var lastPyTorchJobCondition *kubeflowv1.JobCondition
	if len(pytorchJob.Status.Conditions) > 0 {
		lastPyTorchJobCondition = &pytorchJob.Status.Conditions[len(pytorchJob.Status.Conditions)-1]
	}

	pytorchJobInfo := PyTorchJobInfo{
		Name:          pytorchJob.Name,
		Status:        getPyTorchJobStatusFromPods(podsInfo),
		LastCondition: lastPyTorchJobCondition,
		Pods:          podsInfo,
	}

	return &pytorchJobInfo, nil
}

// getPyTorchJobStatusFromPods determines the overall status based on pod statuses
// Returns a map of status counts
func getPyTorchJobStatusFromPods(pods []PodInfo) map[string]int {
	statusCounts := make(map[string]int)
	
	for _, pod := range pods {
		// Determine pod status
		status := string(pod.Phase)
		
		// Check for unschedulable first
		if isPodUnschedulable(pod) {
			status = "Unschedulable"
		} else if containerIssue := getContainerIssues([]PodInfo{pod}); containerIssue != "" {
			// Check for more specific container issues
			status = containerIssue
		}
		
		statusCounts[status]++
	}

	return statusCounts
}

// ============================================================================
// JobSet Status Functionality
// ============================================================================

// getJobSetInfo extracts jobset and associated job/pod information for a specific jobset
func getJobSetInfo(clientset *kubernetes.Clientset, jobsetClient *jobsetclientset.Clientset, namespace, jobsetName string) (*JobSetInfo, error) {
	// Get the specific jobset
	jobset, err := jobsetClient.JobsetV1alpha2().JobSets(namespace).Get(context.TODO(), jobsetName, metav1.GetOptions{})
	if err != nil {
		return nil, err
	}

	// Get jobs for this jobset
	jobs, err := getJobInfoForJobSet(clientset, namespace, jobset.Name)
	if err != nil {
		return nil, err
	}

	// Get last condition if available
	var lastJobSetCondition *metav1.Condition
	if len(jobset.Status.Conditions) > 0 {
		lastJobSetCondition = &jobset.Status.Conditions[len(jobset.Status.Conditions)-1]
	}

	jobsetInfo := JobSetInfo{
		Name:          jobset.Name,
		Status:        getJobSetStatus(jobs),
		Restarts:      jobset.Status.Restarts,
		LastCondition: lastJobSetCondition,
		Jobs:          jobs,
	}

	return &jobsetInfo, nil
}

// getJobSetStatus determines the overall status of JobSet based on job statuses
// Returns a map of status counts
// Example: {"Running": 1, "Pending": 2}
func getJobSetStatus(jobs []JobInfo) map[string]int {
	statusCounts := make(map[string]int)
	
	for _, job := range jobs {
		statusCounts[job.Status]++
	}

	return statusCounts
}

// ============================================================================
// Job Status Functionality
// ============================================================================

// getJobInfoForJobSet extracts job and associated pod information for jobs belonging to a specific jobset
func getJobInfoForJobSet(clientset *kubernetes.Clientset, namespace, jobsetName string) ([]JobInfo, error) {
	// Find jobs created by this jobset using label selector
	labelSelector := fmt.Sprintf("jobset.sigs.k8s.io/jobset-name=%s", jobsetName)
	jobs, err := clientset.BatchV1().Jobs(namespace).List(context.TODO(), metav1.ListOptions{
		LabelSelector: labelSelector,
	})
	if err != nil {
		return nil, err
	}

	var jobsInfo []JobInfo

	for _, job := range jobs.Items {
		// Find pods created by this job
		podLabelSelector := fmt.Sprintf("job-name=%s", job.Name)
		pods, err := clientset.CoreV1().Pods(namespace).List(context.TODO(), metav1.ListOptions{
			LabelSelector: podLabelSelector,
		})
		if err != nil {
			return nil, err
		}

		// Get pod information for this job's pods
		podsInfo := getPodInfo(pods)

		// Get last condition if available
		var lastJobCondition *batchv1.JobCondition
		if len(job.Status.Conditions) > 0 {
			lastJobCondition = &job.Status.Conditions[len(job.Status.Conditions)-1]
		}

		jobInfo := JobInfo{
			Name:           job.Name,
			Status:         getJobStatus(&job, podsInfo),
			StartTime:      job.Status.StartTime,
			CompletionTime: job.Status.CompletionTime,
			LastCondition:  lastJobCondition,
			Pods:           podsInfo,
		}

		jobsInfo = append(jobsInfo, jobInfo)
	}

	return jobsInfo, nil
}

// getJobStatus determines the overall status of a job
func getJobStatus(job *batchv1.Job, pods []PodInfo) string {
	// Check for unschedulable pods first
	if hasUnschedulablePods(pods) {
		return "Unschedulable"
	}

	// Check for container issues (ImagePullError, OOMKilled, CrashLoopBackOff, etc.)
	if containerIssue := getContainerIssues(pods); containerIssue != "" {
		return containerIssue
	}

	// Job is still running
	if job.Status.Active > 0 {
		return "Running"
	}

	// Job conditions are only set upon completion
	if len(job.Status.Conditions) == 0 {
		return "Pending"
	}

	// Return latest condition type
	lc := job.Status.Conditions[len(job.Status.Conditions)-1]
	return string(lc.Type)
}

// ============================================================================
// Pod and Container Functionality
// ============================================================================

// getPodInfo extracts pod and container information from a list of pods
func getPodInfo(pods *corev1.PodList) []PodInfo {
	var podsInfo []PodInfo

	for _, pod := range pods.Items {
		podInfo := PodInfo{
			Name:  pod.Name,
			Phase: pod.Status.Phase,
		}

		// Get last condition if available
		if len(pod.Status.Conditions) > 0 {
			lastCondition := pod.Status.Conditions[len(pod.Status.Conditions)-1]
			podInfo.LastCondition = &lastCondition
		}

		// Process init containers
		for _, initContainer := range pod.Status.InitContainerStatuses {
			podInfo.InitContainers = append(podInfo.InitContainers, ContainerInfo{
				Name:  initContainer.Name,
				State: initContainer.State,
			})
		}

		// Process regular containers
		for _, container := range pod.Status.ContainerStatuses {
			podInfo.Containers = append(podInfo.Containers, ContainerInfo{
				Name:  container.Name,
				State: container.State,
			})
		}

		// Process sidecar containers (ephemeral containers)
		for _, ephemeralContainer := range pod.Status.EphemeralContainerStatuses {
			podInfo.SidecarContainers = append(podInfo.SidecarContainers, ContainerInfo{
				Name:  ephemeralContainer.Name,
				State: ephemeralContainer.State,
			})
		}

		podsInfo = append(podsInfo, podInfo)
	}

	return podsInfo
}

// getContainerIssues checks all containers in pods and returns the first non-running reason found
func getContainerIssues(pods []PodInfo) string {
	for _, pod := range pods {
		// Check init containers
		for _, container := range pod.InitContainers {
			if reason := getContainerIssueReason(container); reason != "" {
				return reason
			}
		}
		// Check regular containers
		for _, container := range pod.Containers {
			if reason := getContainerIssueReason(container); reason != "" {
				return reason
			}
		}
		// Check sidecar containers
		for _, container := range pod.SidecarContainers {
			if reason := getContainerIssueReason(container); reason != "" {
				return reason
			}
		}
	}
	return ""
}

// getContainerIssueReason checks a single container and returns the issue reason if not running
func getContainerIssueReason(container ContainerInfo) string {
	// Check if container is running - if so, no issue
	if container.State.Running != nil {
		return ""
	}

	// Check waiting state (container hasn't started or is restarting)
	if container.State.Waiting != nil {
		return container.State.Waiting.Reason
	}

	// Check terminated state (container has stopped)
	if container.State.Terminated != nil {
		reason := container.State.Terminated.Reason
		// "Completed" with exit code 0 is not an error, it's successful completion
		if reason == "Completed" && container.State.Terminated.ExitCode == 0 {
			return ""
		}
		// "Error" or non-zero exit codes are actual issues
		return reason
	}

	return ""
}

// isPodUnschedulable checks if a single pod has an unschedulable condition
func isPodUnschedulable(pod PodInfo) bool {
	return pod.LastCondition != nil &&
		pod.LastCondition.Type == corev1.PodScheduled &&
		pod.LastCondition.Status == corev1.ConditionFalse &&
		pod.LastCondition.Reason == "Unschedulable"
}

// hasUnschedulablePods checks if any pod has an unschedulable condition
func hasUnschedulablePods(pods []PodInfo) bool {
	for _, pod := range pods {
		if isPodUnschedulable(pod) {
			return true
		}
	}
	return false
}
