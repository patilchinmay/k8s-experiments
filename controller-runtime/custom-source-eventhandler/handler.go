package main

import (
	"context"
	"reflect"

	"github.com/go-logr/logr"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/client-go/util/workqueue"
	"sigs.k8s.io/controller-runtime/pkg/event"
	"sigs.k8s.io/controller-runtime/pkg/handler"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"
)

/*
`handler.EventHandler`` key responsibilities:

- Receives events (create, update, delete, generic) for watched resources.
- Determines which objects need to be reconciled based on these events.
- Creates (enqueues) reconcile requests for the affected objects.
*/

type ExternalEventHandler struct {
	log logr.Logger
}

var _ handler.EventHandler = &ExternalEventHandler{}

func NewExternalEventHandler(log logr.Logger) *ExternalEventHandler {
	return &ExternalEventHandler{
		log: log,
	}
}

// Not implemented since we are only concerned about generic events
func (h *ExternalEventHandler) Create(ctx context.Context, evt event.CreateEvent, q workqueue.RateLimitingInterface) {
	// Handle create events
	h.log.Info("Create ExternalEventHandler", "evt", evt)
}

// Not implemented since we are only concerned about generic events
func (h *ExternalEventHandler) Update(ctx context.Context, evt event.UpdateEvent, q workqueue.RateLimitingInterface) {
	// Handle update events
	h.log.Info("Update ExternalEventHandler", "evt", evt)
}

// Not implemented since we are only concerned about generic events
func (h *ExternalEventHandler) Delete(ctx context.Context, evt event.DeleteEvent, q workqueue.RateLimitingInterface) {
	// Handle delete events
	h.log.Info("Delete ExternalEventHandler", "evt", evt)
}

func (h *ExternalEventHandler) Generic(ctx context.Context, evt event.GenericEvent, q workqueue.RateLimitingInterface) {
	// Handle generic events
	h.log.Info("Generic ExternalEventHandler", "evt", evt)

	if isNil(evt.Object) {
		h.log.Error(nil, "GenericEvent received with no metadata", "event", evt)
		return
	}
	q.Add(reconcile.Request{NamespacedName: types.NamespacedName{
		Name:      evt.Object.GetName(),
		Namespace: evt.Object.GetNamespace(),
	}})
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
