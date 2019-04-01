package kubeless

import (
	"github.com/kubeless/kubeless/pkg/functions"
)

// Hello Kubeless handler function
func Handler(event functions.Event, context functions.Context) (string, error) {
	return "Hello Kubeless!", nil
}
