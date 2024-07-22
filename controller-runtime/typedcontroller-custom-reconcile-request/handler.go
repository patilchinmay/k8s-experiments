package main

import (
	"context"
	"reflect"

	"github.com/go-logr/logr"
	"github.com/google/uuid"
	batchv1 "k8s.io/api/batch/v1"
	"k8s.io/client-go/util/workqueue"
	"sigs.k8s.io/controller-runtime/pkg/event"
	"sigs.k8s.io/controller-runtime/pkg/handler"
)

/*
`handler.TypedEventHandler`` key responsibilities:

- Receives events (create, update, delete, generic) for watched resources.
- Determines which objects need to be reconciled based on these events.
- Creates (enqueues) reconcile requests for the affected objects.
*/

type CustomEventHandler struct {
	log logr.Logger
}

var (
	_ handler.TypedEventHandler[*batchv1.Job, CustomReconcileRequest] = &CustomEventHandler{}
)

func NewCustomEventHandler(log logr.Logger) *CustomEventHandler {
	return &CustomEventHandler{
		log: log,
	}
}

func (h *CustomEventHandler) Create(ctx context.Context, evt event.TypedCreateEvent[*batchv1.Job], q workqueue.TypedRateLimitingInterface[CustomReconcileRequest]) {
	// Handle create events
	userID := uuid.NewString()
	h.log.Info("Create CustomEventHandler", "evt-name", evt.Object.GetName(), "evt-ns", evt.Object.GetNamespace(), "evt-userID", userID)

	if isNil(evt.Object) {
		h.log.Error(nil, "CreateEvent received with no metadata", "event", evt)
		return
	}

	q.Add(CustomReconcileRequest{
		userID: userID,
	})
}

func (h *CustomEventHandler) Update(ctx context.Context, evt event.TypedUpdateEvent[*batchv1.Job], q workqueue.TypedRateLimitingInterface[CustomReconcileRequest]) {
	// Handle update events
	userID := uuid.NewString()
	h.log.Info("Update CustomEventHandler", "old-evt-name", evt.ObjectOld.GetName(), "old-evt-ns", evt.ObjectOld.GetNamespace(), "new-evt-name", evt.ObjectNew.GetName(), "new-evt-ns", evt.ObjectNew.GetNamespace(), "evt-userID", userID)

	switch {
	case !isNil(evt.ObjectNew):
		q.Add(CustomReconcileRequest{
			userID: userID,
		})
	case !isNil(evt.ObjectOld):
		q.Add(CustomReconcileRequest{
			userID: userID,
		})
	default:
		h.log.Error(nil, "UpdateEvent received with no metadata", "event", evt)
	}
}

func (h *CustomEventHandler) Delete(ctx context.Context, evt event.TypedDeleteEvent[*batchv1.Job], q workqueue.TypedRateLimitingInterface[CustomReconcileRequest]) {
	// Handle delete events
	userID := uuid.NewString()
	h.log.Info("Delete CustomEventHandler", "evt-name", evt.Object.GetName(), "evt-ns", evt.Object.GetNamespace(), "evt-userID", userID)

	if isNil(evt.Object) {
		h.log.Error(nil, "DeleteEvent received with no metadata", "event", evt)
		return
	}

	q.Add(CustomReconcileRequest{
		userID: userID,
	})
}

func (h *CustomEventHandler) Generic(ctx context.Context, evt event.TypedGenericEvent[*batchv1.Job], q workqueue.TypedRateLimitingInterface[CustomReconcileRequest]) {
	// Handle generic events
	userID := uuid.NewString()
	h.log.Info("Generic CustomEventHandler", "evt-name", evt.Object.GetName(), "evt-ns", evt.Object.GetNamespace(), "evt-userID", userID)

	if isNil(evt.Object) {
		h.log.Error(nil, "GenericEvent received with no metadata", "event", evt)
		return
	}

	q.Add(CustomReconcileRequest{
		userID: userID,
	})
}

func isNil(arg any) bool {
	if v := reflect.ValueOf(arg); !v.IsValid() || ((v.Kind() == reflect.Ptr ||
		v.Kind() == reflect.Interface ||
		v.Kind() == reflect.Slice ||
		v.Kind() == reflect.Map ||
		v.Kind() == reflect.Chan ||
		v.Kind() == reflect.Func) && v.IsNil()) {
		return true
	}
	return false
}
