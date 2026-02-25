// Package main provides MustWriter for panic-on-error writing (gen-containerfile).
package main

import (
	"fmt"
	"io"
)

// MustWriter wraps an io.Writer and provides helpers that panic on write errors.
//
//nolint:stdmethods
type MustWriter struct {
	w io.Writer
}

// NewMustWriter returns a MustWriter that writes to w.
func NewMustWriter(w io.Writer) *MustWriter {
	return &MustWriter{w: w}
}

// Write writes p and panics on error.
func (mw *MustWriter) Write(p []byte) {
	if _, err := mw.w.Write(p); err != nil {
		panic(err)
	}
}

// WriteString writes s and panics on error.
func (mw *MustWriter) WriteString(s string) {
	mw.Write([]byte(s))
}

// Printf formats and writes, and panics on error.
func (mw *MustWriter) Printf(format string, args ...interface{}) {
	if _, err := fmt.Fprintf(mw.w, format, args...); err != nil {
		panic(err)
	}
}

// WriteByte writes a single byte and panics on error.
func (mw *MustWriter) WriteByte(b byte) {
	mw.Write([]byte{b})
}

// MaxCmdLineLen is the maximum line length for WriteCmd before breaking with \.
// DO NOT CHANGE THIS VALUE since it will cause containers to be rebuilt.
const MaxCmdLineLen = 79

// WriteCmd writes the given args as a single command line, breaking at
// MaxCmdLineLen with " \\\n\t".
//
// Ensure the command arguments are sorted to prevent unnecessary container
// rebuilds.
func (mw *MustWriter) WriteCmd(args ...string) {
	if len(args) == 0 {
		return
	}
	lineLen := 0
	for i, arg := range args {
		need := len(arg)
		if i > 0 {
			need++ // space before arg
		}
		if lineLen > 0 && lineLen+need > MaxCmdLineLen {
			mw.WriteString(" \\\n\t")
			lineLen = 1 + len(arg) // tab + arg
			mw.WriteString(arg)
			continue
		}
		if i > 0 {
			mw.WriteByte(' ')
			lineLen++
		}
		mw.WriteString(arg)
		lineLen += len(arg)
	}
	mw.WriteByte('\n')
}
