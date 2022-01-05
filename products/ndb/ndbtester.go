package main

import (
	"database/sql"
	"fmt"
	"log"
	"time"

	"github.com/go-sql-driver/mysql"
)

type City struct {
	ID          int64
	Name        string
	CountryCode string
	District    string
	Population  int
}

var db *sql.DB

func main() {

	// Capture connection properties.
	cfg := mysql.Config{
		User:   "francisco",
		Passwd: "Majes1tad",
		Net:    "tcp",
		Addr:   "mysql-a:3306",
		DBName: "world",
	}

	var err error
	db, err = sql.Open("mysql", cfg.FormatDSN())
	if err != nil {
		log.Fatal(err)
	}

	pingErr := db.Ping()
	if pingErr != nil {
		log.Fatal(pingErr)
	}

	log.Println("Connected!")

	var count int = 1000

	for j := 0; j < 1; j++ {

		var startTime1 = time.Now()
		fmt.Println("Inserting cities")
		insertCities(count)
		var endTime1 = time.Now()
		fmt.Printf("%d operations per second\n", int64(1000*count)/(endTime1.Sub(startTime1).Milliseconds()))

		var startTime2 = time.Now()
		fmt.Println("Deleting cities")
		deleteCities(count)
		var endTime2 = time.Now()
		fmt.Printf("%d operations per second\n", int64(1000*count)/(endTime2.Sub(startTime2).Milliseconds()))

		cities, err := getCities()
		if err != nil {
			log.Fatal(err)
		}
		fmt.Printf("Found %d cities\n", len(cities))
	}
}

func getCities() ([]City, error) {
	var cities []City

	rows, err := db.Query("select * from city")
	if err != nil {
		return nil, fmt.Errorf("query error %s", err)
	}
	defer rows.Close()

	for rows.Next() {
		var city City
		if err := rows.Scan(&city.ID, &city.Name, &city.District, &city.CountryCode, &city.Population); err != nil {
			return nil, fmt.Errorf("getCities %q: %v", "all", err)
		}
		cities = append(cities, city)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("getCities %q: %v", "all", err)
	}

	return cities, nil
}

func insertCities(count int) {
	stmt, err := db.Prepare("INSERT INTO city (Name, CountryCode, District, Population) VALUES(?, ?, ?, ?)")
	if err != nil {
		log.Fatal(err)
	}
	defer stmt.Close()
	for i := 0; i < count; i++ {
		_, err := stmt.Exec(fmt.Sprintf("City%d", i), "ESP", "DummyDistrict", i)
		if err != nil {
			log.Fatal(err)
		}
	}
}

func deleteCities(count int) {
	stmt, err := db.Prepare("DELETE FROM city where Name = ?")
	if err != nil {
		log.Fatal(err)
	}
	defer stmt.Close()
	for i := 0; i < count; i++ {
		_, err := stmt.Exec(fmt.Sprintf("City%d", i))
		if err != nil {
			log.Fatal(err)
		}
	}
}
