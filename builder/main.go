package main

import (
	"fmt"
	"os"

	tea "github.com/charmbracelet/bubbletea"

	"github.com/yourusername/lumin-build/builder/tui"
)

func main() {
	// Must run as root — hard check before even showing the TUI
	if os.Getuid() != 0 {
		fmt.Fprintln(os.Stderr, "lumin-build must be run as root. Use: sudo ./lumin-build")
		os.Exit(1)
	}

	m := tui.New()

	p := tea.NewProgram(
		m,
		tea.WithAltScreen(),       // full terminal takeover — no scroll back mess
		tea.WithMouseCellMotion(), // optional: mouse scroll in log viewport
	)
	tui.SetProgram(p)

	if _, err := p.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "lumin-build error: %v\n", err)
		os.Exit(1)
	}
}
