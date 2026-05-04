package tui

import "time"

// ── Build pipeline messages ───────────────────────────────────────────────────
// These are sent from the concurrent build goroutines → Bubble Tea Update()

// StageStartMsg fires when a phase script begins executing.
type StageStartMsg struct {
	Index int    // index into the stages slice
	Name  string // human-readable name e.g. "Install KDE Plasma"
}

// StageDoneMsg fires when a phase script exits successfully.
type StageDoneMsg struct {
	Index   int
	Elapsed time.Duration
}

// StageFailMsg fires when a phase script exits with a non-zero code.
type StageFailMsg struct {
	Index int
	Err   error
}

// LogLineMsg is a single line of stdout/stderr from any phase script.
// The TUI appends it to the log viewport.
type LogLineMsg struct {
	Stage string // which stage produced this line
	Line  string
}

// BuildDoneMsg fires when ALL stages have completed successfully.
type BuildDoneMsg struct {
	ISOPath string
	ISOSize int64
	SHA256  string
	Elapsed time.Duration
}

// BuildFailMsg fires when the overall build failed and cannot continue.
type BuildFailMsg struct {
	Stage string
	Err   error
}

// ── Check messages ────────────────────────────────────────────────────────────

// CheckResultMsg is sent by each pre-flight check goroutine.
type CheckResultMsg struct {
	Name   string // "Root", "Network", "Storage" etc.
	Passed bool
	Detail string // e.g. "42 GB free" or "not running as root"
}

// AllChecksPassedMsg fires once every check has passed.
type AllChecksPassedMsg struct{}

// ── Model download messages ───────────────────────────────────────────────────

// ModelProgressMsg streams download progress from builder/model/download.go
type ModelProgressMsg struct {
	BytesDownloaded int64
	TotalBytes      int64
	SpeedBytesPerSec int64
}

// ModelDoneMsg fires when the model file is fully downloaded and verified.
type ModelDoneMsg struct {
	Path string
	Size int64
}