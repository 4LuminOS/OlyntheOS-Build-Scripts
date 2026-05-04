package tui

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"time"

	tea "github.com/charmbracelet/bubbletea"
)

var p *tea.Program

func SetProgram(prog *tea.Program) {
	p = prog
}

// ── Pre-flight checks ─────────────────────────────────────────────────────────

// runChecksCmd runs ALL pre-flight checks concurrently and sends
// CheckResultMsg for each one. Fires AllChecksPassedMsg if all pass,
// or BuildFailMsg if any check fails.
func runChecksCmd(checks []Check) tea.Cmd {
	return func() tea.Msg {
		results := make(chan CheckResultMsg, len(checks))

		// Run each check in its own goroutine — concurrent pre-flight
		go checkRoot(results)
		go checkNetwork(results)
		go checkStorage(results)
		go checkOS(results)
		go checkTools(results)

		// Collect results
		passed := true
		for i := 0; i < len(checks); i++ {
			r := <-results
			if !r.Passed {
				passed = false
			}
			// Note: individual CheckResultMsgs are sent separately via batchCmd
		}

		if passed {
			return AllChecksPassedMsg{}
		}
		return BuildFailMsg{Err: fmt.Errorf("pre-flight checks failed — fix the issues above and retry")}
	}
}

// runChecksStream sends each check result as it arrives (for live UI updates).
// This is what you actually use — returns a batch of Cmds.
func RunChecksStream() tea.Cmd {
	cmds := []tea.Cmd{
		runSingleCheck("Root permissions",              checkRootSync),
		runSingleCheck("Network connectivity",          checkNetworkSync),
		runSingleCheck("Storage space (>20 GB free)",  checkStorageSync),
		runSingleCheck("OS compatibility (Debian/Ubuntu)", checkOSSync),
		runSingleCheck("Required tools (debootstrap, squashfs)", checkToolsSync),
	}
	return tea.Batch(cmds...)
}

func runSingleCheck(name string, fn func() (bool, string)) tea.Cmd {
	return func() tea.Msg {
		passed, detail := fn()
		return CheckResultMsg{Name: name, Passed: passed, Detail: detail}
	}
}

// ── Individual check implementations ─────────────────────────────────────────

func checkRootSync() (bool, string) {
	if os.Getuid() == 0 {
		return true, "running as root"
	}
	return false, "must run as root (use sudo)"
}

func checkNetworkSync() (bool, string) {
	cmd := exec.Command("ping", "-c", "1", "-W", "3", "8.8.8.8")
	if err := cmd.Run(); err != nil {
		return false, "no internet connection"
	}
	return true, "connected"
}

func checkStorageSync() (bool, string) {
	var stat syscallStatfs
	if err := statfs(".", &stat); err != nil {
		return false, "cannot check storage"
	}
	freeGB := (stat.Bavail * uint64(stat.Bsize)) / (1024 * 1024 * 1024)
	if freeGB < 20 {
		return false, fmt.Sprintf("only %d GB free — need at least 20 GB", freeGB)
	}
	return true, fmt.Sprintf("%d GB free", freeGB)
}

func checkOSSync() (bool, string) {
	// Check for debian-based system
	if _, err := os.Stat("/etc/debian_version"); err == nil {
		data, _ := os.ReadFile("/etc/debian_version")
		return true, "Debian " + string(data)
	}
	if _, err := os.Stat("/etc/lsb-release"); err == nil {
		return true, "Ubuntu-based"
	}
	return false, "must be Debian or Ubuntu based"
}

func checkToolsSync() (bool, string) {
	tools := []string{"debootstrap", "mksquashfs", "grub-mkrescue", "xorriso"}
	missing := []string{}
	for _, t := range tools {
		if _, err := exec.LookPath(t); err != nil {
			missing = append(missing, t)
		}
	}
	if len(missing) > 0 {
		return false, "missing: " + joinStrings(missing)
	}
	return true, "all tools found"
}

// Placeholder goroutine versions (used by runChecksCmd above)
func checkRoot(ch chan<- CheckResultMsg) {
	p, d := checkRootSync(); ch <- CheckResultMsg{Name: "Root permissions", Passed: p, Detail: d}
}
func checkNetwork(ch chan<- CheckResultMsg) {
	p, d := checkNetworkSync(); ch <- CheckResultMsg{Name: "Network connectivity", Passed: p, Detail: d}
}
func checkStorage(ch chan<- CheckResultMsg) {
	p, d := checkStorageSync(); ch <- CheckResultMsg{Name: "Storage space (>20 GB free)", Passed: p, Detail: d}
}
func checkOS(ch chan<- CheckResultMsg) {
	p, d := checkOSSync(); ch <- CheckResultMsg{Name: "OS compatibility (Debian/Ubuntu)", Passed: p, Detail: d}
}
func checkTools(ch chan<- CheckResultMsg) {
	p, d := checkToolsSync(); ch <- CheckResultMsg{Name: "Required tools (debootstrap, squashfs)", Passed: p, Detail: d}
}

// ── Build pipeline ────────────────────────────────────────────────────────────

// runBuildCmd is the main concurrent build command.
// It runs each phase script in sequence, streaming log lines to the TUI.
// Each stage fires StageStartMsg → (LogLineMsg...) → StageDoneMsg or StageFailMsg.
func runBuildCmd(stages []Stage, cfg BuildConfig) tea.Cmd {
	return func() tea.Msg {
		// This single Cmd fires the first stage.
		// Each stage, when done, fires the next via its own Cmd.
		// This keeps the Bubble Tea message loop clean.
		return StageStartMsg{Index: 0, Name: stages[0].Name}
	}
}

// RunStageCmd executes one phase script and streams its output.
// When done, it signals the next stage to start.
// Call this from Update() when you receive StageStartMsg.
func RunStageCmd(index int, stages []Stage, cfg BuildConfig, prog *tea.Program) tea.Cmd {
	return func() tea.Msg {
		stage := stages[index]
		start := time.Now()

		// Last stage (ISO packaging) is handled by Go code, not a script
		if stage.Script == "" {
			// TODO: call your Go ISO packager here
			// For now, simulate it
			time.Sleep(2 * time.Second)
			elapsed := time.Since(start)
			if index+1 >= len(stages) {
				return BuildDoneMsg{
					ISOPath: cfg.OutputPath,
					ISOSize: 2_400_000_000,
					SHA256:  "sha256-placeholder",
					Elapsed: time.Since(start),
				}
			}
			prog.Send(StageDoneMsg{Index: index, Elapsed: elapsed})
			return StageStartMsg{Index: index + 1, Name: stages[index+1].Name}
		}

		// Run the phase script
		cmd := exec.Command("bash", stage.Script)

		// Pass build config as env vars to the scripts
		cmd.Env = append(os.Environ(),
			fmt.Sprintf("LUMIN_AI_ENABLED=%v", cfg.AIEnabled),
			fmt.Sprintf("LUMIN_CUDA_ENABLED=%v", cfg.CUDAEnabled),
			fmt.Sprintf("LUMIN_OUTPUT=%s", cfg.OutputPath),
			fmt.Sprintf("LUMIN_BUILD_TYPE=%s", cfg.BuildType),
		)

		// Pipe stdout and stderr
		stdout, err := cmd.StdoutPipe()
		if err != nil {
			return StageFailMsg{Index: index, Err: err}
		}
		stderr, _ := cmd.StderrPipe()

		if err := cmd.Start(); err != nil {
			return StageFailMsg{Index: index, Err: err}
		}

		// Stream stdout lines to TUI
		go func() {
			scanner := bufio.NewScanner(stdout)
			for scanner.Scan() {
				prog.Send(LogLineMsg{Stage: stage.Name, Line: scanner.Text()})
			}
		}()

		// Stream stderr lines to TUI
		go func() {
			scanner := bufio.NewScanner(stderr)
			for scanner.Scan() {
				prog.Send(LogLineMsg{Stage: stage.Name, Line: "E: " + scanner.Text()})
			}
		}()

		// Wait for script to finish
		if err := cmd.Wait(); err != nil {
			return StageFailMsg{Index: index, Err: fmt.Errorf("%s: %w", stage.Name, err)}
		}

		elapsed := time.Since(start)
		prog.Send(StageDoneMsg{Index: index, Elapsed: elapsed})

		// Fire next stage or done
		next := index + 1
		if next >= len(stages) {
			return BuildDoneMsg{
				ISOPath: cfg.OutputPath,
				ISOSize: getISOSize(cfg.OutputPath),
				SHA256:  computeSHA256(cfg.OutputPath),
				Elapsed: time.Since(start),
			}
		}
		return StageStartMsg{Index: next, Name: stages[next].Name}
	}
}

// ── Utilities ─────────────────────────────────────────────────────────────────

func getISOSize(path string) int64 {
	info, err := os.Stat(path)
	if err != nil { return 0 }
	return info.Size()
}

func computeSHA256(path string) string {
	cmd := exec.Command("sha256sum", path)
	out, err := cmd.Output()
	if err != nil { return "error computing hash" }
	// sha256sum output: "hash  filename"
	if len(out) >= 64 {
		return string(out[:64])
	}
	return string(out)
}

func joinStrings(ss []string) string {
	result := ""
	for i, s := range ss {
		if i > 0 { result += ", " }
		result += s
	}
	return result
}

// syscallStatfs and statfs are platform-specific — see cmds_linux.go
// These stubs satisfy the compiler on non-Linux
type syscallStatfs struct {
	Bavail uint64
	Bsize  int64
}

func statfs(path string, stat *syscallStatfs) error {
	// Real implementation in cmds_linux.go using syscall.Statfs
	return nil
}