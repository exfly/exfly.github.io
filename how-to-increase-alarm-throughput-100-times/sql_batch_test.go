package alarmopt

import (
	"sync/atomic"
	"testing"

	"github.com/stretchr/testify/require"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/schema"
)

var (
	DB *gorm.DB
)

func init() {
	var err error
	DB, err = gorm.Open(postgres.New(postgres.Config{
		DSN:                  "postgres://alarmopt:alarmopt@localhost:35432/alarmopt?sslmode=disable", // data source name, refer https://github.com/jackc/pgx
		PreferSimpleProtocol: true,                                                                    // disables implicit prepared statement usage. By default pgx automatically uses the extended protocol
	}), &gorm.Config{NamingStrategy: schema.NamingStrategy{
		SingularTable: true,
	}})
	if err != nil {
		panic(err)
	}

	rawDB, err := DB.DB()
	if err != nil {
		panic(err)
	}

	rawDB.SetMaxOpenConns(2*8 + 1)
}

func testGenAlarm(t *testing.T, size int) []*Alarm {
	var index atomic.Int64
	alarms := make([]*Alarm, 0, size)
	for i := 0; i < size; i++ {
		curr := index.Add(1)

		alarms = append(alarms, &Alarm{ID: int(curr)})
	}

	return alarms
}

const (
	AlarmSize  = 50000
	AlarmBatch = 100
)

// go test -timeout 30s -run ^TestSingleInsert$ github.com/exfly/alarmopt
func TestSingleInsert(t *testing.T) {
	err := DB.AutoMigrate(&Alarm{})
	require.NoError(t, err)
	err = DB.Exec("truncate alarm;").Error
	require.NoError(t, err)

	alarms := testGenAlarm(t, AlarmSize)
	err = DB.Debug().CreateInBatches(alarms, 1).Error
	require.NoError(t, err)
}

// go test -timeout 30s -run ^TestBatchInsert$ github.com/exfly/alarmopt
func TestBatchInsert(t *testing.T) {
	err := DB.AutoMigrate(&Alarm{})
	require.NoError(t, err)
	err = DB.Exec("truncate alarm;").Error
	require.NoError(t, err)

	alarms := testGenAlarm(t, AlarmSize)
	err = DB.Debug().CreateInBatches(alarms, AlarmBatch).Error
	require.NoError(t, err)
}
