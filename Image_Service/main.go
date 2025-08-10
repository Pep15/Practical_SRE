package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	phttp "github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	httpRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests.",
		},
		[]string{"path", "method", "code"},
	)

	httpRequestDurationSeconds = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_duration_seconds",
			Help:    "Duration of HTTP requests in seconds.",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"path", "method", "code"},
	)
)

func init() {
	prometheus.MustRegister(httpRequestsTotal)
	prometheus.MustRegister(httpRequestDurationSeconds)
}

type loggingResponseWriter struct {
	http.ResponseWriter
	statusCode int
}

func (lrw *loggingResponseWriter) WriteHeader(code int) {
	lrw.statusCode = code
	lrw.ResponseWriter.WriteHeader(code)
}

func prometheusMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		lrw := &loggingResponseWriter{ResponseWriter: w, statusCode: http.StatusOK}
		next.ServeHTTP(lrw, r)

		duration := time.Since(start).Seconds()
		httpRequestsTotal.WithLabelValues(r.URL.Path, r.Method, strconv.Itoa(lrw.statusCode)).Inc()
		httpRequestDurationSeconds.WithLabelValues(r.URL.Path, r.Method, strconv.Itoa(lrw.statusCode)).Observe(duration)
	}
}

func uploadImageHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("Received image upload request.")

	if r.Method != http.MethodPost {
		http.Error(w, "Only POST is allowed", http.StatusMethodNotAllowed)
		log.Printf("Method not allowed: %s", r.Method)
		return
	}

	file, handler, err := r.FormFile("image")
	if err != nil {
		http.Error(w, "Error reading file: "+err.Error(), http.StatusBadRequest)
		log.Printf("Error reading file from form: %v", err)
		return
	}
	defer file.Close()

	uploadDir := "uploads"
	if _, err := os.Stat(uploadDir); os.IsNotExist(err) {
		if err := os.MkdirAll(uploadDir, os.ModePerm); err != nil {
			http.Error(w, "Error creating upload directory: "+err.Error(), http.StatusInternalServerError)
			log.Printf("Error creating uploads directory: %v", err)
			return
		}
		log.Printf("Created uploads directory: %s", uploadDir)
	}

	filename := fmt.Sprintf("%d_%s", time.Now().Unix(), handler.Filename)
	fullpath := filepath.Join(uploadDir, filename)

	dst, err := os.Create(fullpath)
	if err != nil {
		http.Error(w, "Error saving file: "+err.Error(), http.StatusInternalServerError)
		log.Printf("Error creating file on disk: %v", err)
		return
	}
	defer dst.Close()

	bytesWritten, err := io.Copy(dst, file)
	if err != nil {
		http.Error(w, "Error writing file to disk: "+err.Error(), http.StatusInternalServerError)
		log.Printf("Error writing file to disk: %v", err)
		return
	}

	imageURL := fmt.Sprintf("https://images.local/uploads/%s", filename)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"image_url": imageURL,
	})

	log.Printf("Saved %d bytes to %s", bytesWritten, fullpath)
	log.Println("Image upload request processed successfully.")
}

func main() {
	http.HandleFunc("/", prometheusMiddleware(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("Image Service is running!"))
	}))

	http.HandleFunc("/images", prometheusMiddleware(func(w http.ResponseWriter, r *http.Request) {
		response := map[string]string{"message": "Image service is ready to handle images"}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(response)
	}))

	http.HandleFunc("/images/upload", prometheusMiddleware(uploadImageHandler))

	http.Handle("/uploads/", http.StripPrefix("/uploads/", http.FileServer(http.Dir("uploads"))))
	http.Handle("/metrics", phttp.Handler())

	log.Println("Image service listening on port 8082")
	if err := http.ListenAndServe(":8082", nil); err != nil {
		log.Fatal(err)
	}
}
