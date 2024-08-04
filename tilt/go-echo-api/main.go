package main

import (
	"log"
	"net/http"
	"time"

	"github.com/labstack/echo/v4"
)

var updateDuration time.Duration

func calcUpdateDuration() time.Duration {
	if StartTime.IsZero() {
		return 0
	}
	return time.Since(StartTime)
}

func updateTimeDisplay() string {
	if updateDuration != 0 {
		return updateDuration.Truncate(100 * time.Millisecond).String()
	}
	return "N/A"
}

func main() {
	updateDuration = calcUpdateDuration()

	e := echo.New()

	e.GET("/", func(c echo.Context) error {
		return c.String(http.StatusOK, "Hello, World!")
	})

	// e.GET("/v2", func(c echo.Context) error {
	// 	return c.String(http.StatusOK, "Hello, World v2!")
	// })

	// e.GET("/v3", func(c echo.Context) error {
	// 	return c.String(http.StatusOK, "Hello, World v3!")
	// })

	log.Printf("Rebuild time: %s\n", updateTimeDisplay())

	e.Logger.Fatal(e.Start(":8000"))
}
