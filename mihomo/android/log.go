package main

import (
	"bytes"
	"os"
	"runtime/debug"
	"sync"

	"github.com/sirupsen/logrus"
)

const (
	logCap  = 2 << 20
	logKeep = 1 << 20
)

type cappedLog struct {
	mu   sync.Mutex
	path string
	file *os.File
	size int64
}

var engineLog *cappedLog

func openLog(path string) error {
	if engineLog != nil && engineLog.path == path {
		return nil
	}
	l := &cappedLog{path: path}
	if err := l.reopen(); err != nil {
		return err
	}
	old := engineLog
	engineLog = l
	logrus.SetOutput(l)
	if old != nil {
		old.mu.Lock()
		old.close()
		old.mu.Unlock()
	}
	if crash, err := os.OpenFile(path, os.O_WRONLY|os.O_APPEND|os.O_CREATE, 0o600); err == nil {
		_ = debug.SetCrashOutput(crash, debug.CrashOptions{})
		_ = crash.Close()
	}
	return nil
}

func (l *cappedLog) reopen() error {
	f, err := os.OpenFile(l.path, os.O_WRONLY|os.O_APPEND|os.O_CREATE, 0o600)
	if err != nil {
		return err
	}
	info, err := f.Stat()
	if err != nil {
		_ = f.Close()
		return err
	}
	l.file, l.size = f, info.Size()
	return nil
}

func (l *cappedLog) Write(p []byte) (int, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.size+int64(len(p)) > logCap {
		l.trim()
	}
	if l.file == nil {
		return len(p), nil
	}
	n, err := l.file.Write(p)
	l.size += int64(n)
	return n, err
}

func (l *cappedLog) trim() {
	data, _ := os.ReadFile(l.path)
	if len(data) > logKeep {
		data = data[len(data)-logKeep:]
		if i := bytes.IndexByte(data, '\n'); i >= 0 {
			data = data[i+1:]
		}
	}
	l.close()
	_ = os.WriteFile(l.path, data, 0o600)
	_ = l.reopen()
}

func (l *cappedLog) close() {
	if l.file != nil {
		_ = l.file.Close()
		l.file = nil
	}
}
