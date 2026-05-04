package checks

import (
	"fmt"
	"net"
)

// NetCheck Attempts to make a http request to the go.dev site to check for network connectivity
//
// PENDING CONCURRENCY IMPLEMENTATION
func NetCheck() (passed bool, err error) {
	conn, err := net.Dial("tcp", "go.dev:http")
	if err != nil {
		return false, fmt.Errorf("connectivity error %v", err)
	}

	defer conn.Close()
	return true, nil
}
