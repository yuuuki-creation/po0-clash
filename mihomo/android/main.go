package main

// #include <stdlib.h>
import "C"

import (
	"errors"
	"fmt"
	"net"
	"os"
	"sync"
	"syscall"
	"time"
	"unsafe"

	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/hub"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/hub/route"
	"github.com/metacubex/mihomo/listener"
	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/tunnel/statistic"
)

var (
	mu         sync.Mutex
	running    bool
	controller string
)

//export po0_mihomo_start
func po0_mihomo_start(homeDir, configPath, logPath *C.char) *C.char {
	if err := start(C.GoString(homeDir), C.GoString(configPath), C.GoString(logPath)); err != nil {
		return C.CString(err.Error())
	}
	return nil
}

//export po0_mihomo_stop
func po0_mihomo_stop() {
	stop()
}

//export po0_mihomo_free
func po0_mihomo_free(p *C.char) {
	C.free(unsafe.Pointer(p))
}

func main() {}

// The cmfa tag (needed: plain Android builds read the root-only package list) also hides the /configs API the core uses.
func init() {
	route.SetEmbedMode(false)
}

func start(homeDir, configPath, logPath string) (err error) {
	mu.Lock()
	defer mu.Unlock()

	if err := openLog(logPath); err != nil {
		return fmt.Errorf("open log: %w", err)
	}
	if err := os.MkdirAll(homeDir, 0o700); err != nil {
		return err
	}
	constant.SetHomeDir(homeDir)
	constant.SetConfig(configPath)

	buf, err := os.ReadFile(configPath)
	if err != nil {
		return err
	}
	raw, err := config.UnmarshalRawConfig(buf)
	if err != nil {
		return fmt.Errorf("parse config: %w", err)
	}
	tunFd := 0
	if raw.Tun.Enable {
		tunFd = raw.Tun.FileDescriptor
	}
	defer func() {
		if r := recover(); r != nil {
			err = fmt.Errorf("mihomo panicked: %v", r)
		}
		if err != nil {
			log.Errorln("[po0] start failed: %s", err)
			releaseTun(tunFd)
		}
	}()

	cfg, err := config.ParseRawConfig(raw)
	if err != nil {
		return fmt.Errorf("parse config: %w", err)
	}
	hub.ApplyConfig(cfg)
	running = true
	controller = cfg.Controller.ExternalControllerUnix
	if controller != "" {
		controller = constant.Path.Resolve(controller)
	}

	if tunFd > 0 && !listener.GetTunConf().Enable {
		shutdown()
		return errors.New("TUN failed to start, see the engine log")
	}
	if controller != "" && !waitController(true) {
		shutdown()
		return errors.New("external controller did not come up")
	}
	return nil
}

func stop() {
	mu.Lock()
	defer mu.Unlock()
	if running {
		shutdown()
	}
}

// The empty config closes every inbound including the TUN fd and resets LastTunConf, so a recycled fd number reopens.
func shutdown() {
	route.ReCreateServer(&route.Config{})
	if controller != "" {
		waitController(false)
	}
	if idle, err := config.Parse([]byte("mode: direct\nlog-level: warning\n")); err == nil {
		executor.ApplyConfig(idle, true)
	}
	statistic.DefaultManager.Range(func(c statistic.Tracker) bool {
		_ = c.Close()
		return true
	})
	executor.Shutdown()
	running = false
	controller = ""
}

// mihomo (re)starts the controller on a goroutine, and the core dials it as soon as start returns.
func waitController(up bool) bool {
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		conn, err := net.DialTimeout("unix", controller, 200*time.Millisecond)
		if conn != nil {
			_ = conn.Close()
		}
		if (err == nil) == up {
			return true
		}
		time.Sleep(20 * time.Millisecond)
	}
	return false
}

// An fd mihomo never took would keep the VPN interface up and black-hole all traffic.
func releaseTun(fd int) {
	if fd <= 0 {
		return
	}
	if target, err := os.Readlink(fmt.Sprintf("/proc/self/fd/%d", fd)); err == nil && target == "/dev/tun" {
		_ = syscall.Close(fd)
	}
}
