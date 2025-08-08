package main

import (
    "context"
    "crypto/sha256"
    "encoding/json"
    "encoding/hex"
    "log"
    "math/rand"
    "net/http"
    "os"
    "strconv"
    "sync/atomic"
    "time"

    "github.com/go-chi/chi/v5"
    "github.com/go-chi/chi/v5/middleware"
    "github.com/jackc/pgx/v5/pgxpool"
    prometheus "github.com/prometheus/client_golang/prometheus"
    promhttp "github.com/prometheus/client_golang/prometheus/promhttp"
)

// Metrics
var (
    totalRequests = prometheus.NewCounterVec(
        prometheus.CounterOpts{Name: "api_requests_total", Help: "Total API requests"},
        []string{"method", "endpoint", "status"},
    )
    successfulRequests = prometheus.NewCounter(
        prometheus.CounterOpts{Name: "api_requests_success_total", Help: "Total successful requests"},
    )
    failedRequests = prometheus.NewCounter(
        prometheus.CounterOpts{Name: "api_requests_failed_total", Help: "Total failed requests"},
    )
    requestDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "api_request_duration_seconds",
            Help:    "API request duration in seconds",
            Buckets: prometheus.DefBuckets,
        },
        []string{"method", "endpoint"},
    )
    activeRequests = prometheus.NewGauge(
        prometheus.GaugeOpts{Name: "api_active_requests", Help: "Active API requests"},
    )
    dbOperations = prometheus.NewCounterVec(
        prometheus.CounterOpts{Name: "db_operations_total", Help: "Total database operations"},
        []string{"operation"},
    )
    dbRowCount = prometheus.NewGauge(
        prometheus.GaugeOpts{Name: "db_rows", Help: "Database rows (approx)"},
    )
    dbSizeBytes = prometheus.NewGauge(
        prometheus.GaugeOpts{Name: "db_size_bytes", Help: "Database size in bytes"},
    )
)

func init() {
    prometheus.MustRegister(totalRequests, successfulRequests, failedRequests, requestDuration, activeRequests, dbOperations, dbRowCount, dbSizeBytes)
}

type Server struct {
    router *chi.Mux
    db     *pgxpool.Pool
}

func main() {
    // Config
    addr := ":8000"
    if p := os.Getenv("PORT"); p != "" {
        addr = ":" + p
    }
    dsn := os.Getenv("DATABASE_URL")
    if dsn == "" {
        // Fallback to k8s ConfigMap default if not set
        dsn = "postgres://postgres:postgres@postgres-service:5432/testdb?sslmode=disable"
    }

    // DB pool
    ctx := context.Background()
    dbpool, err := pgxpool.New(ctx, dsn)
    if err != nil {
        log.Fatalf("failed to create db pool: %v", err)
    }
    defer dbpool.Close()

    // Background DB metrics collector
    go func() {
        ticker := time.NewTicker(10 * time.Second)
        defer ticker.Stop()
        for range ticker.C {
            collectDBMetrics(ctx, dbpool)
        }
    }()

    s := &Server{
        router: chi.NewRouter(),
        db:     dbpool,
    }

    s.routes()
    log.Printf("API listening on %s", addr)
    if err := http.ListenAndServe(addr, s.router); err != nil {
        log.Fatal(err)
    }
}

func (s *Server) routes() {
    r := s.router
    r.Use(middleware.RealIP)
    r.Use(middleware.Recoverer)
    r.Use(s.prometheusMiddleware)

    r.Get("/", func(w http.ResponseWriter, r *http.Request) {
        ok(w, map[string]any{"message": "Kubernetes Test Lab Go API", "docs": "/metrics", "health": "/health"})
    })
    r.Get("/health", func(w http.ResponseWriter, r *http.Request) { ok(w, map[string]string{"status": "healthy"}) })
    r.Handle("/metrics", promhttp.Handler())

    // Simple endpoints for load/metrics testing
    r.Post("/cpu-intensive", s.cpuIntensive)
    r.Post("/memory-intensive", s.memoryIntensive)
    r.Post("/simulate-delay", s.simulateDelay)
    r.Get("/stats", s.stats)
}

// Middleware for metrics per request
func (s *Server) prometheusMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        activeRequests.Inc()

        ww := &statusWriter{ResponseWriter: w, status: 200}
        next.ServeHTTP(ww, r)

        duration := time.Since(start).Seconds()
        endpoint := r.URL.Path
        totalRequests.WithLabelValues(r.Method, endpoint, strconv.Itoa(ww.status)).Inc()
        requestDuration.WithLabelValues(r.Method, endpoint).Observe(duration)
        activeRequests.Dec()

        if ww.status >= 200 && ww.status < 400 {
            successfulRequests.Inc()
        } else {
            failedRequests.Inc()
        }
    })
}

type statusWriter struct {
    http.ResponseWriter
    status int
}

func (w *statusWriter) WriteHeader(statusCode int) {
    w.status = statusCode
    w.ResponseWriter.WriteHeader(statusCode)
}

// Handlers
func (s *Server) cpuIntensive(w http.ResponseWriter, r *http.Request) {
    iterations := 1000000
    if v := r.URL.Query().Get("iterations"); v != "" {
        if n, err := strconv.Atoi(v); err == nil && n > 0 {
            iterations = n
        }
    }

    var acc uint64
    for i := 0; i < iterations; i++ {
        atomic.AddUint64(&acc, uint64(i*i))
        if i%100000 == 0 {
            // let scheduler breathe
            time.Sleep(0)
        }
    }
    // add some hashing work
    h := sha256.Sum256([]byte(strconv.FormatUint(acc, 10)))
    ok(w, map[string]any{"iterations": iterations, "hash": hex.EncodeToString(h[:])})
}

func (s *Server) memoryIntensive(w http.ResponseWriter, r *http.Request) {
    sizeMB := 10
    if v := r.URL.Query().Get("size_mb"); v != "" {
        if n, err := strconv.Atoi(v); err == nil && n > 0 && n <= 100 {
            sizeMB = n
        }
    }

    blocks := make([][]byte, sizeMB)
    for i := 0; i < sizeMB; i++ {
        blocks[i] = make([]byte, 1024*1024)
        // touch memory
        for j := range blocks[i] {
            blocks[i][j] = byte(rand.Intn(256))
        }
    }
    // use the memory briefly
    sum := 0
    for i := 0; i < sizeMB; i++ {
        sum += int(blocks[i][0])
    }
    _ = sum
    ok(w, map[string]any{"allocated_mb": sizeMB})
}

func (s *Server) simulateDelay(w http.ResponseWriter, r *http.Request) {
    delay := 1.0
    if v := r.URL.Query().Get("delay_seconds"); v != "" {
        if f, err := strconv.ParseFloat(v, 64); err == nil && f >= 0 && f <= 10 {
            delay = f
        }
    }
    time.Sleep(time.Duration(delay * float64(time.Second)))
    ok(w, map[string]any{"message": "ok", "delay_seconds": delay})
}

func (s *Server) stats(w http.ResponseWriter, r *http.Request) {
    ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
    defer cancel()
    // Example: count rows in a demo table if exists, else 0
    var cnt int64
    if err := s.db.QueryRow(ctx, "SELECT COUNT(*) FROM information_schema.tables").Scan(&cnt); err == nil {
        dbRowCount.Set(float64(cnt))
    }
    // Database size in bytes (approx)
    var sizeBytes int64
    if err := s.db.QueryRow(ctx, "SELECT COALESCE(SUM(pg_database_size(datname)),0) FROM pg_database").Scan(&sizeBytes); err == nil {
        dbSizeBytes.Set(float64(sizeBytes))
    }
    dbOperations.WithLabelValues("stats").Inc()
    ok(w, map[string]any{"db_rows": cnt, "db_size_bytes": sizeBytes})
}

// Helpers
func ok(w http.ResponseWriter, v any) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusOK)
    b, err := json.Marshal(v)
    if err != nil {
        b = []byte("{}")
    }
    w.Write(b)
}

func collectDBMetrics(ctx context.Context, db *pgxpool.Pool) {
    ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
    defer cancel()
    var sizeBytes int64
    if err := db.QueryRow(ctx, "SELECT COALESCE(SUM(pg_database_size(datname)),0) FROM pg_database").Scan(&sizeBytes); err == nil {
        dbSizeBytes.Set(float64(sizeBytes))
    }
}

