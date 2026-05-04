package tui

import "github.com/charmbracelet/lipgloss"

// ── Colour palette ────────────────────────────────────────────────────────────
// Edit these to customise the entire TUI in one place.
const (
	colorPurple  = "#9B8AFB" // LuminOS brand purple
	colorGreen   = "#1D9E75"
	colorYellow  = "#E3B341"
	colorRed     = "#FF4444"
	colorBlue    = "#58A6FF"
	colorDimGray = "#484F58"
	colorGray    = "#8B949E"
	colorWhite   = "#F0F6FC"
	colorBg      = "#0D1117" // terminal bg (used for contrast checks)
)

// ── Base styles ───────────────────────────────────────────────────────────────

var (
	// Title bar at the top of the screen
	TitleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color(colorWhite)).
			Background(lipgloss.Color(colorPurple)).
			Padding(0, 3)

	// Subtitle / version string next to the title
	SubtitleStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color(colorGray)).
			Padding(0, 1)

	// Section labels like "BUILD STAGES" or "LIVE LOG"
	SectionLabelStyle = lipgloss.NewStyle().
				Foreground(lipgloss.Color(colorPurple)).
				Bold(true)

	// Rounded border box — used around the log viewport
	BorderBoxStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color(colorDimGray)).
			Padding(0, 1)

	// Footer hint line
	FooterStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color(colorDimGray))
)

// ── Stage status styles ───────────────────────────────────────────────────────

var (
	StageDoneStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color(colorGreen)).
			Bold(true)

	StageRunStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color(colorPurple)).
			Bold(true)

	StageFailStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color(colorRed)).
			Bold(true)

	StagePendStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color(colorDimGray))

	StageNameStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color(colorWhite))

	StageDetailStyle = lipgloss.NewStyle().
				Foreground(lipgloss.Color(colorGray))
)

// ── Done screen styles ────────────────────────────────────────────────────────

var (
	DoneHeaderStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color(colorGreen))

	ErrorHeaderStyle = lipgloss.NewStyle().
				Bold(true).
				Foreground(lipgloss.Color(colorRed))

	ISOPathStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color(colorBlue)).
			Bold(true)

	MetaKeyStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color(colorGray))

	MetaValStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color(colorWhite))

	HashStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color(colorYellow)).
			Bold(true)
)

// ── Config screen styles ──────────────────────────────────────────────────────

var (
	InputLabelStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color(colorGray)).
			Bold(true)

	InputActiveStyle = lipgloss.NewStyle().
				Foreground(lipgloss.Color(colorPurple)).
				Bold(true)

	SelectedItemStyle = lipgloss.NewStyle().
				Foreground(lipgloss.Color(colorPurple)).
				Bold(true)

	NormalItemStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color(colorGray))

	CheckOnStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color(colorGreen)).
			Bold(true)

	CheckOffStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color(colorDimGray))
)

// ── Log line styles ───────────────────────────────────────────────────────────

var (
	LogTimeStyle  = lipgloss.NewStyle().Foreground(lipgloss.Color(colorDimGray))
	LogInfoStyle  = lipgloss.NewStyle().Foreground(lipgloss.Color(colorGray))
	LogOKStyle    = lipgloss.NewStyle().Foreground(lipgloss.Color(colorGreen))
	LogWarnStyle  = lipgloss.NewStyle().Foreground(lipgloss.Color(colorYellow))
	LogErrorStyle = lipgloss.NewStyle().Foreground(lipgloss.Color(colorRed))
)