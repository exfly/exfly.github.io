package alarmopt

import (
	"context"
	"log/slog"
	"os"
	"strconv"
	"sync"
	"testing"
	"time"
)

var (
	logger = slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{AddSource: true, Level: slog.LevelDebug}))
	// logger = slog.New(slog.NewJSONHandler(os.Stderr, &slog.HandlerOptions{AddSource: true, Level: slog.LevelDebug}))
)

type Alarm struct {
	ID int
}

func (a Alarm) String() string {
	return strconv.Itoa(a.ID)
}

type batchInsert struct {
	do           func(context.Context, []Alarm) error
	interval     time.Duration
	maxBatchSize int64

	lock sync.RWMutex
	buf  []Alarm

	once sync.Once
}

func (b *batchInsert) Do(ctx context.Context, in Alarm) error {
	b.once.Do(func() {
		go func() {
			ticker := time.NewTicker(b.interval)

			for range ticker.C {
				if b.lock.TryLock() {
					if len(b.buf) > 0 {
						logger.Info("timer do")
						if err := b.do(ctx, b.buf); err != nil {
							logger.Error("in ticker do failed", "err", err)
						} else if err == nil {
							b.buf = nil
						}
					}
					b.lock.Unlock()
				}
			}
		}()
	})

	b.lock.Lock()
	defer b.lock.Unlock()

	if b.buf == nil {
		b.buf = make([]Alarm, 0, b.maxBatchSize)
	}
	b.buf = append(b.buf, in)
	if len(b.buf) >= int(b.maxBatchSize) {
		logger.Info("realtime do")
		if err := b.do(ctx, b.buf); err != nil {
			logger.Error("do failed", "err", err)
		} else if err == nil {
			b.buf = nil
		}

	}
	return nil
}

var (
	spendTimes   time.Duration = 1
	testTxSpend                = time.Second / 10 * spendTimes
	testRowSpend               = time.Second / 20 * spendTimes
)

func testRealDo(ctx context.Context, in []Alarm) error {
	time.Sleep(testTxSpend)
	time.Sleep(testRowSpend * time.Duration(len(in)))

	ids := make([]int, 0, len(in))
	for _, one := range in {
		ids = append(ids, one.ID)
	}
	logger.Debug("real do", "ids", ids)
	return nil
}

// go test --trimpath -timeout 30s -run ^TestRawBatch$ github.com/exfly/alarmopt -v
func TestRawBatch(t *testing.T) {
	ctx := context.Background()

	batchs := &batchInsert{do: testRealDo, interval: time.Second, maxBatchSize: 5}

	for i := 0; i < 50; i++ {
		time.Sleep(time.Second / 6)
		logger.Debug("submit", "i", i)
		_ = batchs.Do(ctx, Alarm{ID: i})
	}

	logger.Info("", "batch", batchs)
}
