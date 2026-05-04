//go:build linux
// +build linux

package tui

import "golang.org/x/sys/unix"

// statfs is implemented for Linux using unix.Statfs to populate our
// lightweight `syscallStatfs` struct used by the TUI checks.
func statfs(path string, stat *syscallStatfs) error {
    var s unix.Statfs_t
    if err := unix.Statfs(path, &s); err != nil {
        return err
    }
    // Convert platform fields into our struct
    stat.Bavail = uint64(s.Bavail)
    // Bsize may be a different integer type on some platforms — normalize
    stat.Bsize = int64(s.Bsize)
    return nil
}
