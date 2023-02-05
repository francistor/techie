package main

import (
	"bytes"
	"crypto/tls"
	"flag"
	"fmt"
	"io"
	"math/rand"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"golang.org/x/net/http2"
)

// TODO: General comments
// TODO: Generate certificates
// TODO: Add -sqlclient
// TODO: document that filename may point to a volume

/*
Executes performance tests of various types, typically in a Kubernetes cluster
*/

// The file to be written by the server
var serverFile *os.File
var doSync bool

// Configuration variables
var sliceSize int = 1024 * 1024
var numSlices int = 1000
var fileSize = sliceSize * numSlices

func main() {

	// Get the command line arguments
	fileNamePtr := flag.String("filename", "/tmp/simpleprofiler/profilerfile", "File Path and name of file to write to and read from")
	securePtr := flag.Bool("https", false, "whether to use https")
	serverHostPtr := flag.String("serverhost", "localhost", "name or ip address of the profiler server")
	serverPortPtr := flag.Int("serverport", 8080, "port where the profiler server listens for http(s) requests")
	// -----> Start here sqlUrl := flag.String("sqlurl", "", "mysql url for root user. Example ")
	isServerPtr := flag.Bool("server", false, "whether to run as server")
	isClientPtr := flag.Bool("client", false, "whether to run as client")
	doSyncPtr := flag.Bool("sync", false, "whether to flush file to disk")

	flag.Parse()

	fileName := *fileNamePtr
	secure := *securePtr
	serverHost := *serverHostPtr
	serverPort := *serverPortPtr
	isServer := *isServerPtr
	isClient := *isClientPtr
	doSync = *doSyncPtr

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
				err = http.ListenAndServeTLS(fmt.Sprintf(":%d", serverPort), "cert.pem", "key.pem", nil)
			} else {
				err = http.ListenAndServe(fmt.Sprintf(":%d", serverPort), nil)
			}
			if err != nil {
				fmt.Printf("[ERROR] server not started due to %s\n", err)
				os.Exit(1)
			}
		}()
	}

	if isClient {

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
			fmt.Printf("[RESULT] write local file. Speed: %f MBytes/sec\n", speed)
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
