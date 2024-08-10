package alarmopt

import (
	"context"
	"testing"
	"time"

	dataloader "github.com/graph-gophers/dataloader/v7"
)

func TestDataloaderNoCache(t *testing.T) {
	batchFunc := func(_ context.Context, keys []int) []*dataloader.Result[*Alarm] {
		var results []*dataloader.Result[*Alarm]
		// do some pretend work to resolve keys
		for _, k := range keys {
			results = append(results, &dataloader.Result[*Alarm]{Data: &Alarm{ID: k}})
		}
		logger.Debug("real do", "ids", keys)
		return results
	}

	cache := &dataloader.NoCache[int, *Alarm]{}
	loader := dataloader.NewBatchedLoader(
		batchFunc,
		dataloader.WithCache[int, *Alarm](cache),
		dataloader.WithWait[int, *Alarm](time.Second*3),
		dataloader.WithBatchCapacity[int, *Alarm](5),
		dataloader.WithInputCapacity[int, *Alarm](1),
	)

	for i := 0; i < 50; i++ {
		logger.Debug("submit", "id", i)
		loader.Load(context.Background(), i)
	}
}

func TestAlarmDataloaderNoCache(t *testing.T) {
	batchFunc := func(_ context.Context, keys []Alarm) []*dataloader.Result[*Alarm] {
		var results []*dataloader.Result[*Alarm]
		// do some pretend work to resolve keys
		for _, k := range keys {
			results = append(results, &dataloader.Result[*Alarm]{Data: &Alarm{ID: k.ID}})
		}
		logger.Debug("real do", "ids", keys)
		return results
	}

	cache := &dataloader.NoCache[Alarm, *Alarm]{}
	loader := dataloader.NewBatchedLoader(
		batchFunc,
		dataloader.WithCache[Alarm, *Alarm](cache),
		dataloader.WithWait[Alarm, *Alarm](time.Second*3),
		dataloader.WithBatchCapacity[Alarm, *Alarm](5),
		dataloader.WithInputCapacity[Alarm, *Alarm](1),
	)

	for i := 0; i < 50; i++ {
		logger.Debug("submit", "id", i)
		loader.Load(context.Background(), Alarm{ID: i})
	}
}

func TestAlarmDataloaderNoCacheRetResult(t *testing.T) {
	batchFunc := func(_ context.Context, keys []Alarm) []*dataloader.Result[*Alarm] {
		var results []*dataloader.Result[*Alarm]
		// do some pretend work to resolve keys
		for _, k := range keys {
			results = append(results, &dataloader.Result[*Alarm]{Data: &Alarm{ID: k.ID}})
		}
		logger.Debug("real do", "ids", keys)
		return results
	}

	cache := &dataloader.NoCache[Alarm, *Alarm]{}
	loader := dataloader.NewBatchedLoader(
		batchFunc,
		dataloader.WithCache[Alarm, *Alarm](cache),
		dataloader.WithWait[Alarm, *Alarm](time.Second*3),
		dataloader.WithBatchCapacity[Alarm, *Alarm](5),
		dataloader.WithInputCapacity[Alarm, *Alarm](1),
	)

	for i := 0; i < 50; i++ {
		logger.Debug("submit", "id", i)
		result, err := loader.Load(context.Background(), Alarm{ID: i})()
		if err != nil {
			t.Error(err)
		}
		_ = result
	}
}

func batchFunc(_ context.Context, keys []Alarm) []*dataloader.Result[*Alarm] {
	var results []*dataloader.Result[*Alarm]
	// do some pretend work to resolve keys
	for _, k := range keys {
		results = append(results, &dataloader.Result[*Alarm]{Data: &Alarm{ID: k.ID}})
	}
	logger.Debug("real do", "len_ids", len(keys))
	// logger.Debug("real do", "ids", keys)
	return results
}

func newAlarmBatchInsertDL(wait time.Duration, batchCap int, inputCap int) *dataloader.Loader[Alarm, *Alarm] {
	cache := &dataloader.NoCache[Alarm, *Alarm]{}
	loader := dataloader.NewBatchedLoader(
		batchFunc,
		dataloader.WithCache[Alarm, *Alarm](cache),
		dataloader.WithWait[Alarm, *Alarm](wait),
		dataloader.WithBatchCapacity[Alarm, *Alarm](batchCap),
		dataloader.WithInputCapacity[Alarm, *Alarm](inputCap),
	)

	return loader
}

func BatchInsert(dl *dataloader.Loader[Alarm, *Alarm], alarm Alarm) error {
	dl.Load(context.Background(), alarm)
	return nil
}

func checkError(err error) {
	if err != nil {
		panic(err)
	}
}

// go test -benchmem -run=^$ -bench '^Benchmark.*$' github.com/exfly/alarmopt -v
func BenchmarkBatchInsert(b *testing.B) {
	dl := newAlarmBatchInsertDL(time.Second, 200, 1)
	err := DB.AutoMigrate(&Alarm{})
	checkError(err)
	err = DB.Exec("truncate alarm;").Error
	checkError(err)
	b.ResetTimer()

	for i := 0; i < b.N; i++ {
		BatchInsert(dl, Alarm{ID: i})
	}
}

func TestBatchMark(t *testing.T) {
	for times := 0; times < 1000; times++ {
		batchCap := 3 * times
		wait := time.Second * 10
		result := testing.Benchmark(func(b *testing.B) {
			t.Logf("wait %v, batchcap %v", wait, batchCap)
			dl := newAlarmBatchInsertDL(wait, batchCap, 1)
			err := DB.AutoMigrate(&Alarm{})
			checkError(err)
			err = DB.Exec("truncate alarm;").Error
			checkError(err)
			b.ResetTimer()

			for i := 0; i < b.N; i++ {
				BatchInsert(dl, Alarm{ID: i})
			}
		})
		t.Logf("%v", result)
	}
}
