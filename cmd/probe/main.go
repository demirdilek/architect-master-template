package main

import (
	"fmt"
	"net/http"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// Definition des Metrik-Vektors (SLI: Latenz)
var (
	latencyGauge = prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "hybrid_link_latency_ms",
		Help: "Current latency between Ubuntu controller and GKE in milliseconds.",
	})
)

func init() {
	// Registrierung der Metrik bei Prometheus
	prometheus.MustRegister(latencyGauge)
}

func measureLatency(target string) {
	for {
		start := time.Now()
		resp, err := http.Get(target)
		duration := time.Since(start)

		if err != nil {
			fmt.Printf("Error probing %s: %v\n", target, err)
		} else {
			resp.Body.Close()
			// Update der Metrik
			latencyGauge.Set(float64(duration.Milliseconds()))
			fmt.Printf("Probe success: %s | Latency: %v\n", target, duration)
		}
		
		// Wartezeit zwischen den Probes (SRE-Best-Practice: Nicht den Link fluten)
		time.Sleep(10 * time.Second)
	}
}

func main() {
	// Starte die Messung in einem eigenen Thread (Goroutine)
	go measureLatency("https://www.google.com")

	// Exponiere die Metriken für Prometheus/Grafana über HTTP
	fmt.Println("Starting metrics server on :8080/metrics")
	http.Handle("/metrics", promhttp.Handler())
	http.ListenAndServe(":8080", nil)
}
