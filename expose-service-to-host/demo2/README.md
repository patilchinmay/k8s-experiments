# Visitor Site

Source: [Kubernetes Operator's Book](https://github.com/kubernetes-operators-book/chapters/tree/master)

Note: The image is changed from `mysql:5.7` to `mariadb:10.5` due to compatibility issue.

## Steps

```
kind create cluster --config kind.yaml
kubectl apply -f database.yaml
kubectl apply -f backend.yaml
kubectl apply -f frontend.yaml

visit http://localhost:30686/ in browser.
```