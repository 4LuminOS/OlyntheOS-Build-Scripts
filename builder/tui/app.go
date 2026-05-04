package tui

import (
	"fmt"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/bubbles/progress"
	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/viewport"
	"github.com/charmbracelet/lipgloss"
)

// ── Screen enum ───────────────────────────────────────────────────────────────

type Screen int

const (
	ScreenConfig  Screen = iota // user picks build options before starting
	ScreenChecks                // pre-flight checks running
	ScreenBuild                 // main build progress view
	ScreenDone                  // success
	ScreenError                 // fatal error
)

// ── Stage definition ──────────────────────────────────────────────────────────

type StageStatus int

const (
	StatusPending StageStatus = iota
	StatusRunning
	StatusDone
	StatusFailed
)

type Stage struct {
	Name   string      // "Install KDE Plasma"
	Script string      // "phases/03-install-desktop.sh"
	Detail string      // "287 packages"  (filled in during run)
	Status StageStatus
	Start  time.Time
	End    time.Time
}

// ── Pre-flight check ──────────────────────────────────────────────────────────

type Check struct {
	Name   string
	Passed bool
	Detail string
	Done   bool
}

// ── Root model ────────────────────────────────────────────────────────────────

type AppModel struct {
	screen  Screen
	width   int
	height  int
	started time.Time

	// Pre-flight checks
	checks []Check

	// Build stages — maps 1:1 to your phases/ scripts
	stages     []Stage
	currentStg int

	// Bubble Tea components
	bar      progress.Model
	spin     spinner.Model
	logView  viewport.Model
	logLines []string
	pct      float64

	// Config screen state
	cfg BuildConfig

	// Done screen
	isoPath string
	isoSize int64
	isoHash string
	elapsed time.Duration

	// Error state
	buildErr   error
	failStage  string

	// Log toggle
	showLog bool
}

// BuildConfig holds the options the user sets on the config screen.
type BuildConfig struct {
	OutputPath  string
	BuildType   string // "standard" | "minimal" | "dev"
	CUDAEnabled bool
	AIEnabled   bool
}

// New creates the initial AppModel with sensible defaults.
func New() AppModel {
	bar := progress.New(
		progress.WithDefaultGradient(),
		progress.WithWidth(50),
	)

	sp := spinner.New()
	sp.Spinner = spinner.Dot
	sp.Style = StageRunStyle

	vp := viewport.New(80, 10)

	return AppModel{
		screen:  ScreenConfig,
		started: time.Now(),
		bar:     bar,
		spin:    sp,
		logView: vp,
		showLog: true,

		cfg: BuildConfig{
			OutputPath:  "./output/luminos.iso",
			BuildType:   "standard",
			CUDAEnabled: false,
			AIEnabled:   true,
		},

		checks: []Check{
			{Name: "Root permissions"},
			{Name: "Network connectivity"},
			{Name: "Storage space (>20 GB free)"},
			{Name: "OS compatibility (Debian/Ubuntu)"},
			{Name: "Required tools (debootstrap, squashfs)"},
		},

		// These map directly to your phases/ scripts
		stages: []Stage{
			{Name: "Filesystem setup",      Script: "phases/02-configure-system.sh"},
			{Name: "Install KDE Plasma",    Script: "phases/03-install-desktop.sh"},
			{Name: "Customise desktop",     Script: "phases/04-customize-desktop.sh"},
			{Name: "Install AI engine",     Script: "phases/05-install-ai.sh"},
			{Name: "Install software",      Script: "phases/08-install-software.sh"},
			{Name: "Plymouth theme",        Script: "phases/07-install-plymouth-theme.sh"},
			{Name: "Final cleanup",         Script: "phases/06-final-cleanup.sh"},
			{Name: "Package ISO",           Script: ""},  // handled by Go, not a script
		},
	}
}

// ── Init ──────────────────────────────────────────────────────────────────────

func (m AppModel) Init() tea.Cmd {
	return tea.Batch(
		m.spin.Tick,
		tea.EnterAltScreen,
	)
}

// ── Update ────────────────────────────────────────────────────────────────────

func (m AppModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmds []tea.Cmd

	switch msg := msg.(type) {

	// ── Window resize ─────────────────────────────────────────────────────────
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		logH := m.height - 22
		if logH < 4 { logH = 4 }
		m.logView = viewport.New(m.width-6, logH)
		m.bar = progress.New(
			progress.WithDefaultGradient(),
			progress.WithWidth(m.width-20),
		)

	// ── Keyboard ──────────────────────────────────────────────────────────────
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "q":
			if m.screen == ScreenDone || m.screen == ScreenError {
				return m, tea.Quit
			}
		case "enter":
			if m.screen == ScreenConfig {
				// Start build — switch to checks screen and fire checks
				m.screen = ScreenChecks
				return m, runChecksCmd(m.checks)
			}
			if m.screen == ScreenDone || m.screen == ScreenError {
				return m, tea.Quit
			}
		case "l":
			m.showLog = !m.showLog
		case "up", "k":
			m.logView.LineUp(1)
		case "down", "j":
			m.logView.LineDown(1)
		case "pgup":
			m.logView.HalfViewUp()
		case "pgdown":
			m.logView.HalfViewDown()
		}

		// Config screen key handling
		if m.screen == ScreenConfig {
			m, cmd := m.updateConfig(msg)
			return m, cmd
		}

	// ── Spinner tick ──────────────────────────────────────────────────────────
	case spinner.TickMsg:
		var cmd tea.Cmd
		m.spin, cmd = m.spin.Update(msg)
		cmds = append(cmds, cmd)

	// ── Progress bar animation ────────────────────────────────────────────────
	case progress.FrameMsg:
		pm, cmd := m.bar.Update(msg)
		m.bar = pm.(progress.Model)
		cmds = append(cmds, cmd)

	// ── Pre-flight check results ──────────────────────────────────────────────
	case CheckResultMsg:
		for i := range m.checks {
			if m.checks[i].Name == msg.Name {
				m.checks[i].Passed = msg.Passed
				m.checks[i].Detail = msg.Detail
				m.checks[i].Done = true
				break
			}
		}

	case AllChecksPassedMsg:
		m.screen = ScreenBuild
		m.started = time.Now()
		cmds = append(cmds, runBuildCmd(m.stages, m.cfg))

	// ── Build stage events ────────────────────────────────────────────────────
	case StageStartMsg:
		if msg.Index < len(m.stages) {
			m.stages[msg.Index].Status = StatusRunning
			m.stages[msg.Index].Start = time.Now()
			m.currentStg = msg.Index
		}
		m.pct = float64(msg.Index) / float64(len(m.stages))
		cmds = append(cmds, m.bar.SetPercent(m.pct))
		cmds = append(cmds, RunStageCmd(msg.Index, m.stages, m.cfg, p))

	case StageDoneMsg:
		if msg.Index < len(m.stages) {
			m.stages[msg.Index].Status = StatusDone
			m.stages[msg.Index].End = time.Now()
			m.stages[msg.Index].Detail = fmt.Sprintf("%.1fs", msg.Elapsed.Seconds())
		}

	case StageFailMsg:
		if msg.Index < len(m.stages) {
			m.stages[msg.Index].Status = StatusFailed
		}
		m.screen = ScreenError
		m.buildErr = msg.Err
		if msg.Index < len(m.stages) {
			m.failStage = m.stages[msg.Index].Name
		}

	// ── Log lines from phase scripts ──────────────────────────────────────────
	case LogLineMsg:
		line := formatLogLine(msg)
		m.logLines = append(m.logLines, line)
		// Keep last 500 lines
		if len(m.logLines) > 500 {
			m.logLines = m.logLines[len(m.logLines)-500:]
		}
		m.logView.SetContent(strings.Join(m.logLines, "\n"))
		m.logView.GotoBottom()

	// ── Build complete ────────────────────────────────────────────────────────
	case BuildDoneMsg:
		m.screen = ScreenDone
		m.isoPath = msg.ISOPath
		m.isoSize = msg.ISOSize
		m.isoHash = msg.SHA256
		m.elapsed = msg.Elapsed
		cmds = append(cmds, m.bar.SetPercent(1.0))

	case BuildFailMsg:
		m.screen = ScreenError
		m.buildErr = msg.Err
		m.failStage = msg.Stage
	}

	return m, tea.Batch(cmds...)
}

// updateConfig handles keyboard input on the config screen.
func (m AppModel) updateConfig(msg tea.KeyMsg) (AppModel, tea.Cmd) {
	switch msg.String() {
	case "a":
		m.cfg.AIEnabled = !m.cfg.AIEnabled
	case "c":
		m.cfg.CUDAEnabled = !m.cfg.CUDAEnabled
	case "1":
		m.cfg.BuildType = "minimal"
	case "2":
		m.cfg.BuildType = "standard"
	case "3":
		m.cfg.BuildType = "dev"
	}
	return m, nil
}

// ── View ──────────────────────────────────────────────────────────────────────

func (m AppModel) View() string {
	switch m.screen {
	case ScreenConfig:
		return m.viewConfig()
	case ScreenChecks:
		return m.viewChecks()
	case ScreenBuild:
		return m.viewBuild()
	case ScreenDone:
		return m.viewDone()
	case ScreenError:
		return m.viewError()
	}
	return ""
}

// ── Config screen ─────────────────────────────────────────────────────────────

func (m AppModel) viewConfig() string {
	var b strings.Builder

	b.WriteString(m.header())
	b.WriteString("\n\n")
	b.WriteString(SectionLabelStyle.Render("BUILD OPTIONS") + "\n\n")

	// Build type
	b.WriteString(InputLabelStyle.Render("  Build type:") + "\n")
	types := []struct{ key, label, val string }{
		{"1", "Minimal  ", "minimal"},
		{"2", "Standard ", "standard"},
		{"3", "Dev      ", "dev"},
	}
	for _, t := range types {
		prefix := "  [" + t.key + "] "
		if m.cfg.BuildType == t.val {
			b.WriteString(SelectedItemStyle.Render(prefix+"● "+t.label) + "\n")
		} else {
			b.WriteString(NormalItemStyle.Render(prefix+"○ "+t.label) + "\n")
		}
	}

	b.WriteString("\n")
	b.WriteString(InputLabelStyle.Render("  Options:") + "\n")

	// AI toggle
	aiCheck := CheckOffStyle.Render("  [a] ○ ")
	if m.cfg.AIEnabled {
		aiCheck = CheckOnStyle.Render("  [a] ● ")
	}
	b.WriteString(aiCheck + StageNameStyle.Render("Include AI engine (lumin-engine)") + "\n")

	// CUDA toggle
	cudaCheck := CheckOffStyle.Render("  [c] ○ ")
	if m.cfg.CUDAEnabled {
		cudaCheck = CheckOnStyle.Render("  [c] ● ")
	}
	b.WriteString(cudaCheck + StageNameStyle.Render("CUDA support (requires Nvidia GPU on build machine)") + "\n")

	b.WriteString("\n")
	b.WriteString(InputLabelStyle.Render("  Output: ") + ISOPathStyle.Render(m.cfg.OutputPath) + "\n")

	b.WriteString("\n\n")
	b.WriteString(FooterStyle.Render("  [enter] start build   [q] quit"))

	return b.String()
}

// ── Checks screen ─────────────────────────────────────────────────────────────

func (m AppModel) viewChecks() string {
	var b strings.Builder

	b.WriteString(m.header())
	b.WriteString("\n\n")
	b.WriteString(SectionLabelStyle.Render("PRE-FLIGHT CHECKS") + "\n\n")

	for _, c := range m.checks {
		var icon, nameS, detailS string
		if !c.Done {
			icon = m.spin.View()
			nameS = StageRunStyle.Render(c.Name)
		} else if c.Passed {
			icon = StageDoneStyle.Render("✓")
			nameS = StageNameStyle.Render(c.Name)
			detailS = StageDetailStyle.Render("  " + c.Detail)
		} else {
			icon = StageFailStyle.Render("✗")
			nameS = StageNameStyle.Render(c.Name)
			detailS = StageFailStyle.Render("  " + c.Detail)
		}
		b.WriteString(fmt.Sprintf("  %s  %s%s\n", icon, nameS, detailS))
	}

	return b.String()
}

// ── Build screen ──────────────────────────────────────────────────────────────

func (m AppModel) viewBuild() string {
	var b strings.Builder

	b.WriteString(m.header())
	b.WriteString("\n\n")

	// Left: stage list
	var stagesStr strings.Builder
	stagesStr.WriteString(SectionLabelStyle.Render("BUILD STAGES") + "\n\n")
	for i, s := range m.stages {
		var icon, nameS, detailS string
		switch s.Status {
		case StatusDone:
			icon = StageDoneStyle.Render("✓")
			nameS = StageNameStyle.Render(s.Name)
			detailS = StageDetailStyle.Render("  " + s.Detail)
		case StatusRunning:
			icon = m.spin.View()
			nameS = StageRunStyle.Render(s.Name)
			detailS = StageDetailStyle.Render("  running...")
		case StatusFailed:
			icon = StageFailStyle.Render("✗")
			nameS = StageFailStyle.Render(s.Name)
		default:
			_ = i
			icon = StagePendStyle.Render("○")
			nameS = StagePendStyle.Render(s.Name)
		}
		stagesStr.WriteString(fmt.Sprintf("  %s  %s%s\n", icon, nameS, detailS))
	}

	b.WriteString(stagesStr.String())
	b.WriteString("\n")

	// Progress bar
	elapsed := time.Since(m.started).Round(time.Second)
	b.WriteString(fmt.Sprintf("  %s  %s\n\n",
		m.bar.View(),
		StageDetailStyle.Render(fmt.Sprintf("%.0f%%  %s elapsed", m.pct*100, elapsed)),
	))

	// Log viewport
	if m.showLog {
		b.WriteString(SectionLabelStyle.Render("  LIVE LOG") + "\n")
		b.WriteString(BorderBoxStyle.Render(m.logView.View()) + "\n")
	}

	b.WriteString(FooterStyle.Render("  [l] toggle log   [↑↓/jk] scroll   [ctrl+c] abort"))

	return b.String()
}

// ── Done screen ───────────────────────────────────────────────────────────────

func (m AppModel) viewDone() string {
	var b strings.Builder

	b.WriteString(m.header())
	b.WriteString("\n\n")
	b.WriteString(DoneHeaderStyle.Render("  ✓ Build complete!") + "\n\n")

	b.WriteString(MetaKeyStyle.Render("  ISO path  : ") + ISOPathStyle.Render(m.isoPath) + "\n")
	b.WriteString(MetaKeyStyle.Render("  Size      : ") + MetaValStyle.Render(formatBytes(m.isoSize)) + "\n")
	b.WriteString(MetaKeyStyle.Render("  SHA256    : ") + HashStyle.Render(m.isoHash) + "\n")
	b.WriteString(MetaKeyStyle.Render("  Time      : ") + MetaValStyle.Render(m.elapsed.Round(time.Second).String()) + "\n")

	b.WriteString("\n")
	b.WriteString(FooterStyle.Render("  [enter] or [q] to exit"))

	return b.String()
}

// ── Error screen ──────────────────────────────────────────────────────────────

func (m AppModel) viewError() string {
	var b strings.Builder

	b.WriteString(m.header())
	b.WriteString("\n\n")
	b.WriteString(ErrorHeaderStyle.Render("  ✗ Build failed") + "\n\n")

	if m.failStage != "" {
		b.WriteString(MetaKeyStyle.Render("  Stage : ") + StageFailStyle.Render(m.failStage) + "\n")
	}
	if m.buildErr != nil {
		b.WriteString(MetaKeyStyle.Render("  Error : ") + LogErrorStyle.Render(m.buildErr.Error()) + "\n")
	}

	b.WriteString("\n")
	b.WriteString(SectionLabelStyle.Render("  LAST LOG LINES") + "\n")

	// Show last 15 log lines for diagnosis
	lines := m.logLines
	if len(lines) > 15 {
		lines = lines[len(lines)-15:]
	}
	for _, l := range lines {
		b.WriteString("  " + l + "\n")
	}

	b.WriteString("\n")
	b.WriteString(FooterStyle.Render("  [enter] or [q] to exit"))

	return b.String()
}

// ── Shared header ─────────────────────────────────────────────────────────────

func (m AppModel) header() string {
	title := TitleStyle.Render("  lumin-build  ")
	sub := SubtitleStyle.Render("LuminOS ISO Builder · v0.1")
	return lipgloss.JoinHorizontal(lipgloss.Center, title, sub)
}

// ── Helpers ───────────────────────────────────────────────────────────────────

// formatLogLine styles a log line based on content.
func formatLogLine(msg LogLineMsg) string {
	line := msg.Line
	switch {
	case strings.HasPrefix(line, "E:") || strings.Contains(line, "error") || strings.Contains(line, "Error"):
		return LogErrorStyle.Render(line)
	case strings.HasPrefix(line, "W:") || strings.Contains(line, "warn"):
		return LogWarnStyle.Render(line)
	case strings.HasPrefix(line, "✓") || strings.Contains(line, "done") || strings.Contains(line, "complete"):
		return LogOKStyle.Render(line)
	default:
		return LogInfoStyle.Render(line)
	}
}

func formatBytes(b int64) string {
	const unit = 1024
	if b < unit {
		return fmt.Sprintf("%d B", b)
	}
	div, exp := int64(unit), 0
	for n := b / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %cB", float64(b)/float64(div), "KMGTPE"[exp])
}