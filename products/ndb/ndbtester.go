package main

import (
	"database/sql"
	"fmt"
	"log"

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
		Addr:   "vm9:3306",
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

	cities, err := getCities()
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("Cities found %v\n", cities)
}

func getCities() ([]City, error) {
	var cities []City

	rows, err := db.Query("select * from city")
	if err != nil {
		return nil, fmt.Errorf("Query error", err)
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
