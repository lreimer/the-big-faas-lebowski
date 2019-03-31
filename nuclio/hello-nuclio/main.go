package main

import (
	"github.com/nuclio/nuclio-sdk-go"
)

func Handler(context *nuclio.Context, event nuclio.Event) (interface{}, error) {
  return nuclio.Response{
		StatusCode:  200,
		ContentType: "text/plain",
		Body:        []byte("Hello from Nuclio!"),
	}, nil
}
