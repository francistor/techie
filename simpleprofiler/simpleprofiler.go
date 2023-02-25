package main

import (
	"bytes"
	"context"
	"crypto/tls"
	"database/sql"
	"errors"
	"flag"
	"fmt"
	"io"
	"math/rand"
	"net/http"
	"os"
	"path/filepath"
	"sync"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"golang.org/x/net/http2"
)

// TODO: General comments
// TODO: document that filename may point to a volume

// Start database with docker run --name mysql -e MYSQL_ROOT_PASSWORD=root -d -p 3306:3306 -d mysql:8.0.32

/*
Executes performance tests of various types, typically in a Kubernetes cluster
*/

// The file to be written by the server
var serverFile *os.File
var doSync bool
var debug bool
var insertThreads int = 0

// Configuration variables
// For file creation and data transfer
var sliceSize int = 1024 * 1024
var numSlices int = 1000
var fileSize = sliceSize * numSlices

// Number of inserts/selects/deletes per round
var sqlLoopSize int

func main() {

	// Get the command line arguments
	fileNamePtr := flag.String("filename", "/tmp/simpleprofiler/profilerfile", "File Path and name of file to write to and read from")
	securePtr := flag.Bool("https", false, "whether to use https")
	serverHostPtr := flag.String("serverhost", "localhost", "name or ip address of the profiler server")
	serverPortPtr := flag.Int("serverport", 8080, "port where the profiler server listens for http(s) requests")
	sqlLoopSizePtr := flag.Int("sqlloopsize", 100, "number of inserts/selects/deletions per iteration")
	sqlCredentialsPtr := flag.String("sqlcredentials", "", "mysql url for root user:password")
	sqlHostPortPtr := flag.String("sqlhostport", "", "mysql url for root user:password")
	sqlQueryPtr := flag.String("sqlquery", "", "query to execute in a query only test. Only select will be executed")
	sqlInsertThreadsPtr := flag.Int("sqlinsertthreads", 0, "execute a sql insert test with multiple threads, and only this test. This parameter specifies the number of threads")
	isServerPtr := flag.Bool("server", false, "whether to run as server")
	isClientPtr := flag.Bool("client", false, "whether to run as client")
	doSyncPtr := flag.Bool("sync", false, "whether to flush file to disk")
	debugPtr := flag.Bool("debug", false, "whether to print debug log")

	flag.Parse()

	fileName := *fileNamePtr
	secure := *securePtr
	serverHost := *serverHostPtr
	serverPort := *serverPortPtr
	isServer := *isServerPtr
	isClient := *isClientPtr

	sqlCredentials := *sqlCredentialsPtr
	sqlHostPort := *sqlHostPortPtr
	sqlQuery := *sqlQueryPtr
	sqlLoopSize = *sqlLoopSizePtr

	debug = *debugPtr
	doSync = *doSyncPtr
	insertThreads = *sqlInsertThreadsPtr

	if debug {
		fmt.Println("[DEBUG] debug is on")
	}

	// Create the certificates
	certFile, keyFile := EnsureCertificates()

	var schema string = "http"
	if secure {
		schema = "https"
	}

	// Sanity checks
	if !isServer && !isClient {
		fmt.Println("[ERROR] -server or -client or both must be specified")

		// Exit with error
		os.Exit(1)
	}

	fmt.Printf("[INFO] writing to file %s\n", fileName)
	if isServer {
		fmt.Printf("[INFO] listening in port %d\n", serverPort)
		if secure {
			fmt.Println("[INFO] using https")
		} else {
			fmt.Println("[INFO] using http")
		}
	}

	if isClient {
		fmt.Printf("[INFO] sending data to %s:/%s:%d\n", schema, serverHost, serverPort)
	}

	fmt.Println("-------------------------------------------------")
	fmt.Println("starting test")
	fmt.Println("-------------------------------------------------")

	// Publish Handlers
	http.HandleFunc("/write", writeFileHandler)
	http.HandleFunc("/discard", discardHandler)
	http.HandleFunc("/close", closeHandler)
	http.HandleFunc("/ping", pingHandler)

	if isServer {

		// Open the file for writing
		// This file will receive the contents sent by the profiler client
		var ferr error
		if serverFile, ferr = prepareFile(fileName + ".server"); ferr != nil {
			fmt.Printf("[ERROR] could not create file %s due to %s\n", fileName, ferr)
			os.Exit(1)
		}

		// Start the server
		go func() {
			var err error
			if secure {
				err = http.ListenAndServeTLS(fmt.Sprintf(":%d", serverPort), certFile, keyFile, nil)
			} else {
				err = http.ListenAndServe(fmt.Sprintf(":%d", serverPort), nil)
			}
			if !errors.Is(err, http.ErrServerClosed) {
				fmt.Printf("[ERROR] server not started due to %s\n", err)
				os.Exit(1)
			}
		}()
	}

	if isClient {

		// Do sql test if so specified
		if sqlCredentials != "" {
			testSql(sqlCredentials, sqlHostPort, sqlQuery)
			// It never finishes
		}

		// Create http client
		var httpClient http.Client
		if schema == "https" {
			httpClient = http.Client{
				Timeout: 5 * time.Second,
				Transport: &http2.Transport{
					TLSClientConfig: &tls.Config{InsecureSkipVerify: true}, // ignore expired SSL certificates
				},
			}
		} else {
			httpClient = http.Client{
				Timeout: 5 * time.Second,
			}
		}

		// Wait util the server responds to ping
		waitForServer(httpClient, schema, serverHost, serverPort)

		// Write to the specified local file and measure speed
		if speed, err := testWriteFile(fileName + ".client"); err != nil {
			fmt.Printf("[ERROR] could not write file %s.client due to %s\n", fileName, err)
			os.Exit(1)
		} else {
			fmt.Printf("[RESULT] write local file. Speed: %f MByte/sec\n", speed)
		}

		// Send contents to the server, where it will not be written to file but discarded
		if speed, err := sendRandom(httpClient, schema, serverHost, serverPort, "discard", false); err != nil {
			fmt.Printf("[ERROR] error sending data %s", err)
			os.Exit(1)
		} else {
			fmt.Printf("[RESULT] data transfer with discard at destination. Speed %f Mbit/sec\n", speed*8)
		}

		// Send contents to the server, where it will be written to file
		if speed, err := sendRandom(httpClient, schema, serverHost, serverPort, "write", true); err != nil {
			fmt.Printf("[ERROR] error sending data %s", err)
			os.Exit(1)
		} else {
			fmt.Printf("[RESULT] data transfer with write at destination. Speed %f Mbit/sec = %f MByte/sec\n", speed*8, speed)
		}

		// Send close command
		closeServer(httpClient, schema, serverHost, serverPort)

		// Finished
	}

	// Wait here until the client sends "close" command
	if isServer {
		time.Sleep(500 * time.Second)
		os.Exit(1)
	}
}

// Opens the file for writing
// making sure directory exists, etc.
func prepareFile(fileName string) (*os.File, error) {

	// Delete file if exists
	if _, err := os.Stat(fileName); err != nil {
		if !os.IsNotExist(err) {
			return nil, err
		}
	} else {
		os.Remove(fileName)
		fmt.Printf("[INFO] existing file %s deleted\n", fileName)
	}

	// Make sure directory exists
	if err := os.MkdirAll(filepath.Dir(fileName), 0777); err != nil {
		return nil, err
	}

	var file *os.File
	var ferr error
	if file, ferr = os.Create(fileName); ferr != nil {
		return nil, ferr
	}

	return file, nil
}

// Writes a file with random contents in the specified location
// The previous file, if any, is deleted
// Returns the writing sepeed
func testWriteFile(fileName string) (float64, error) {

	// Generate a random slice of 1MB
	myBytes := make([]byte, sliceSize)
	if n, err := rand.Read(myBytes); n != sliceSize || err != nil {
		if err != nil {
			return 0, err
		} else {
			return 0, fmt.Errorf("[ERROR] the random bytes generated where not up to the specified size %d", sliceSize)
		}
	}

	// Open file for writing
	var file *os.File
	var ferr error
	if file, ferr = prepareFile(fileName); ferr != nil {
		return 0, ferr
	}
	defer file.Close()

	startTime := time.Now()

	// Write to the file
	for i := 0; i < numSlices; i++ {
		if _, err := file.Write(myBytes); err != nil {
			return 0, err
		}

		if doSync {
			file.Sync()
		}
	}

	endTime := time.Now()
	diff := endTime.Sub(startTime)

	return float64(fileSize/(1024*1024)) / diff.Seconds(), nil
}

// Writes random bytes to the server
func sendRandom(httpClient http.Client, schema string, host string, port int, path string, sendClose bool) (float64, error) {

	sendURL := fmt.Sprintf("%s://%s:%d/%s", schema, host, port, path)

	startTime := time.Now()

	// Generate a random slice of 1MB
	myBytes := make([]byte, sliceSize)
	if n, err := rand.Read(myBytes); n != sliceSize || err != nil {
		if err != nil {
			return 0, err
		} else {
			return 0, fmt.Errorf("the random bytes generated where not up to 1MB")
		}
	}

	// Send multiple slices
	for i := 0; i < numSlices; i++ {
		httpResp, err := httpClient.Post(sendURL, "text/plain", bytes.NewReader(myBytes))
		if err != nil {
			return 0, err
		}
		defer httpResp.Body.Close()

		if httpResp.StatusCode != 200 {
			return 0, fmt.Errorf("received status code %d when sending bytes", httpResp.StatusCode)
		}
	}

	endTime := time.Now()
	diff := endTime.Sub(startTime)

	return float64(fileSize/(1024*1024)) / diff.Seconds(), nil
}

func waitForServer(httpClient http.Client, schema string, host string, port int) {

	sendURL := fmt.Sprintf("%s://%s:%d/%s", schema, host, port, "ping")

	for {
		httpResp, err := httpClient.Get(sendURL)
		if err == nil {
			httpResp.Body.Close()
			if httpResp.StatusCode == 200 {
				break
			}
		}

		fmt.Println("[INFO] waiting for server to be up")
		time.Sleep(2 * time.Second)
	}
}

func closeServer(httpClient http.Client, schema string, host string, port int) {

	sendURL := fmt.Sprintf("%s://%s:%d/%s", schema, host, port, "close")

	httpResp, err := httpClient.Get(sendURL)
	if err == nil {
		httpResp.Body.Close()
	} else {
		fmt.Printf("[ERROR] close server error: %s\n", err)
	}
}

////////////////////////////////////////////////////////////////
// HTTP Handlers
////////////////////////////////////////////////////////////////

// Copy the bytes received to the file
func writeFileHandler(w http.ResponseWriter, req *http.Request) {

	if _, err := io.Copy(serverFile, req.Body); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusOK)

	if doSync {
		serverFile.Sync()
	}
}

// Discards the received content
func discardHandler(w http.ResponseWriter, req *http.Request) {

	if _, err := io.Copy(io.Discard, req.Body); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusOK)
}

// Terminate this executable
func closeHandler(w http.ResponseWriter, req *http.Request) {

	serverFile.Close()

	// Read blindly and do nothing with the data
	io.ReadAll(req.Body)
	w.WriteHeader(http.StatusOK)

	// Program exit
	time.AfterFunc(1*time.Second, func() {
		// Exit with no error
		os.Exit(0)
	})
}

// Health check
func pingHandler(w http.ResponseWriter, req *http.Request) {
	w.WriteHeader(http.StatusOK)
}

// ///////////////////////////////////////////////////////////
type T struct {
	Id  int
	Val int
}

// This function never ends. It executes an infinite loop of insertions, selections and deletions of the
// same data.
func testSql(sqlCredentials string, sqlHostPort string, sqlQuery string) {

	dbHandle, err := sql.Open("mysql", fmt.Sprintf("%s@tcp(%s)/mysql?parseTime=true&multiStatements=true", sqlCredentials, sqlHostPort))

	if err != nil {
		fmt.Printf("[ERROR] could not open database due to %s\n", err)
		os.Exit(1)
	}
	dbHandle.SetMaxOpenConns(1)
	dbHandle.SetMaxIdleConns(1)

	err = dbHandle.Ping()
	if err != nil {
		fmt.Printf("[ERROR] could not ping database: %s\n", err)
		os.Exit(1)
	}
	fmt.Println("[INFO] Database ping OK")

	// Execute select only of query is specified
	if sqlQuery != "" {
		for {
			_, err = dbHandle.Exec(sqlQuery)
			if err != nil {
				fmt.Printf("[ERROR] could not execute query %s\n", err)
			}
			fmt.Print("O")
			time.Sleep(200 * time.Millisecond)

			// Never ends
		}
	}

	// Create test table
	_, err = dbHandle.Exec("DROP TABLE IF EXISTS test; CREATE TABLE test (Id INT PRIMARY KEY, Val VARCHAR(32) NOT NULL);")
	if err != nil {
		fmt.Printf("[ERROR] could not create table: %s\n", err)
		os.Exit(1)
	}
	fmt.Println("[INFO] Database test created")

	// Prepare test table
	dbHandle.Exec("delete from test")

	if insertThreads != 0 {
		/* Insertion performance */

		dbHandle.SetMaxOpenConns(insertThreads)
		dbHandle.SetMaxIdleConns(insertThreads)

		c := make(chan int)
		var wg sync.WaitGroup
		for i := 0; i < 20; i++ {
			wg.Add(1)
			go func() {
				defer wg.Done()
				for v := range c {
					_, err = dbHandle.Exec("insert into test (Id, Val) values (?, ?)", v, v)
					if err != nil {
						fmt.Printf("[ERROR] error inserting data: %s\n", err)
						os.Exit(1)
					}
				}
			}()
		}
		st := time.Now()
		for i := range [100]int{} {
			c <- i
		}
		close(c)
		wg.Wait()
		et := time.Now()
		fmt.Printf("\n[DEBUG] Insert %.0f\n", float64(100)/et.Sub(st).Seconds())

		// cleanup
		dbHandle.Exec("delete from test")

		os.Exit(0)
	}

	///////////////////////////////////////

	var startTime time.Time
	var endTime time.Time

	for {
		ctx, _ := context.WithTimeout(context.Background(), 10*time.Second)
		// Insert rows
		startTime = time.Now()
		insertError := false
		for i := 0; i < sqlLoopSize; i++ {
			_, err = dbHandle.ExecContext(ctx, "insert into test (Id, Val) values (?, ?)", i, i)
			if err != nil {
				fmt.Printf("[ERROR] error inserting data: %s\n", err)
				insertError = true
				break
			}
		}

		if !insertError {
			fmt.Print("+")
			endTime := time.Now()
			if debug {
				fmt.Printf("\n[DEBUG] Insert %.0f\n", float64(sqlLoopSize)/endTime.Sub(startTime).Seconds())
			}
		} else {
			fmt.Print("!")
			time.Sleep(1 * time.Second)
		}

		// Select rows
		startTime = time.Now()
		selectError := false
		for i := 0; i < sqlLoopSize; i++ {
			rows, err := dbHandle.QueryContext(ctx, "select Id, Val from test where Id = ?", i)
			if err != nil {
				fmt.Printf("[ERROR] error inserting data: %s\n", err)
				selectError = true
				break
			} else {
				for rows.Next() {
					var t T
					rows.Scan(t.Id, t.Val)
				}
				rows.Close()
			}
		}

		if !selectError {
			fmt.Print("O")
			endTime = time.Now()
			if debug {
				fmt.Printf("\n[DEBUG] Select %.0f\n", float64(sqlLoopSize)/endTime.Sub(startTime).Seconds())
			}
		} else {
			fmt.Print("!")
			time.Sleep(1 * time.Second)
		}

		// Delete rows
		startTime = time.Now()
		deleteError := false
		for i := 0; i < sqlLoopSize; i++ {
			_, err = dbHandle.ExecContext(ctx, "delete from test where Id = ?", i)
			if err != nil {
				fmt.Printf("[ERROR] error deleting data: %s\n", err)
				deleteError = true
				break
			}
		}

		if !deleteError {
			fmt.Print("-")
			endTime = time.Now()
			if debug {
				fmt.Printf("\n[DEBUG] Delete %.0f\n", float64(sqlLoopSize)/endTime.Sub(startTime).Seconds())
			}
		} else {
			fmt.Print("!")
			time.Sleep(1 * time.Second)
		}

		time.Sleep(100 * time.Millisecond)
	}

}
