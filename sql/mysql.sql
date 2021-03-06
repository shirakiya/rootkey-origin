CREATE TABLE IF NOT EXISTS account (
    id                  INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,
    account_id          VARCHAR(20),
    account_password    VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS search (
    search_id               INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,
    search_department_word  VARCHAR(255),
    search_destination_word VARCHAR(255),
    search_keyword          VARCHAR(255),
    search_mode             VARCHAR(40),
    search_radius           INTEGER,
    search_name             VARCHAR(255),
    search_created_at       TIMESTAMP,
    search_updated_at       TIMESTAMP,
    search_account_id       INTEGER
);

CREATE TABLE IF NOT EXISTS waypoint (
    waypoint_id         INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,
    waypoint_search_id  INTEGER,
    waypoint_account_id INTEGER,
    waypoint_word       VARCHAR(255),
    waypoint_lat        FLOAT,
    waypoint_lng        FLOAT
);

CREATE TABLE IF NOT EXISTS result (
    result_id               INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,
    result_search_id        INTEGER,
    result_institution_id   VARCHAR(255),
    result_institution_lat  FLOAT,
    result_institution_lng  FLOAT,
    result_institution_name VARCHAR(255),
    result_reference        VARCHAR(511),
    result_created_at       TIMESTAMP
)
