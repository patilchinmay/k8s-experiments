# Function Reuse Map

```mermaid
%%{init: {'theme':'dark'}}%%
flowchart TB
    subgraph Shared[Shared Utility Functions]
        direction TB
        getPodInfo["getPodInfo()<br/>Extract pod & container details"]
        getContainerIssues["getContainerIssues()<br/>Check all containers in pods"]
        getContainerIssueReason["getContainerIssueReason()<br/>Check single container state"]
        isPodUnschedulable["isPodUnschedulable()<br/>Check single pod condition"]
        hasUnschedulablePods["hasUnschedulablePods()<br/>Check any pod unschedulable"]
    end
    
    subgraph JobSetFlow[JobSet Flow Functions]
        direction TB
        getJobInfoForJobSet["getJobInfoForJobSet()"]
        getJobStatus["getJobStatus()"]
        getJobSetStatus["getJobSetStatus()"]
    end
    
    subgraph PyTorchFlow[PyTorchJob Flow Functions]
        direction TB
        getPyTorchJobInfo["getPyTorchJobInfo()"]
        getPyTorchJobStatusFromPods["getPyTorchJobStatusFromPods()"]
    end
    
    %% JobSet Flow connections
    getJobInfoForJobSet -->|calls| getPodInfo
    getJobStatus -->|calls| hasUnschedulablePods
    getJobStatus -->|calls| getContainerIssues
    
    %% PyTorchJob Flow connections
    getPyTorchJobInfo -->|calls| getPodInfo
    getPyTorchJobStatusFromPods -->|calls| isPodUnschedulable
    getPyTorchJobStatusFromPods -->|calls| getContainerIssues
    
    %% Shared function dependencies
    hasUnschedulablePods -->|calls| isPodUnschedulable
    getContainerIssues -->|calls| getContainerIssueReason
    
    style Shared fill:#4a4a00,stroke:#ffeb3b,stroke-width:3px,color:#fff
    style JobSetFlow fill:#1b5e20,stroke:#66bb6a,stroke-width:3px,color:#fff
    style PyTorchFlow fill:#4a148c,stroke:#ce93d8,stroke-width:3px,color:#fff
    
    style getPodInfo fill:#6d4c00,stroke:#ffd54f,stroke-width:2px,color:#fff
    style getContainerIssues fill:#6d4c00,stroke:#ffd54f,stroke-width:2px,color:#fff
    style getContainerIssueReason fill:#6d4c00,stroke:#ffd54f,stroke-width:2px,color:#fff
    style isPodUnschedulable fill:#6d4c00,stroke:#ffd54f,stroke-width:2px,color:#fff
    style hasUnschedulablePods fill:#6d4c00,stroke:#ffd54f,stroke-width:2px,color:#fff
```

## Function Reuse Summary

### Shared Functions (Used by Both JobSet and PyTorchJob)

| Function | Purpose | Used By |
|----------|---------|---------|
| `getPodInfo()` | Extract pod and container information from Kubernetes pod list | `getJobInfoForJobSet()`, `getPyTorchJobInfo()` |
| `getContainerIssues()` | Check all containers in pods for issues (ImagePullError, CrashLoopBackOff, etc.) | `getJobStatus()`, `getPyTorchJobStatusFromPods()` |
| `getContainerIssueReason()` | Check individual container state and return issue reason | `getContainerIssues()` |
| `isPodUnschedulable()` | Check if a single pod has unschedulable condition | `hasUnschedulablePods()`, `getPyTorchJobStatusFromPods()` |
| `hasUnschedulablePods()` | Check if any pod in a list is unschedulable | `getJobStatus()` |

### Flow-Specific Functions

**JobSet Flow:**
- `getJobInfoForJobSet()` - Get job information for a JobSet
- `getJobStatus()` - Determine status of a single Job
- `getJobSetStatus()` - Aggregate status from all Jobs

**PyTorchJob Flow:**
- `getPyTorchJobInfo()` - Get PyTorchJob information
- `getPyTorchJobStatusFromPods()` - Aggregate status directly from Pods