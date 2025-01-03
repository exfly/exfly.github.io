// Copyright (c) 2016 Arista Networks, Inc.
// Use of this source code is governed by the Apache License 2.0
// that can be found in the COPYING file.

// Package monotime provides a fast monotonic clock source.
package monotime_test

import (
	"testing"
	"time"

	"github.com/exfly/timetiker/pkg/monotime"
)

// go test -timeout 30s -run ^TestNow$ github.com/exfly/timetiker/pkg/monotime -v
func TestNow(t *testing.T) {
	for i := 0; i < 100; i++ {
		t1 := monotime.Now()
		t2 := monotime.Now()
		// I honestly thought that we needed >= here, but in some environments
		// two consecutive calls can return the same value!
		if t1 > t2 {
			t.Fatalf("t1=%d should have been less than or equal to t2=%d", t1, t2)
		}
		t.Log(t1)
		t.Log(t2)
	}

	time.Now()
}
