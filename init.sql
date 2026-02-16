-- Table for activity_types.csv
CREATE TABLE activity_types (
    id INT PRIMARY KEY,
    name VARCHAR(255),
    active VARCHAR(10),
    type VARCHAR(50)
);

-- Table for activity.csv
CREATE TABLE activity (
    activity_id INT,
    type VARCHAR(50),
    assigned_to_user INT,
    deal_id INT,
    done BOOLEAN,
    due_to TIMESTAMP
);

-- Table for deal_changes.csv
CREATE TABLE deal_changes (
    deal_id INT,
    change_time TIMESTAMP,
    changed_field_key VARCHAR(50),
    new_value VARCHAR(255)
);

-- Table for fields.csv
CREATE TABLE fields (
    ID INT PRIMARY KEY,
    FIELD_KEY VARCHAR(50),
    NAME VARCHAR(255),
    FIELD_VALUE_OPTIONS JSONB
);

-- Table for stages.csv
CREATE TABLE stages (
    stage_id INT PRIMARY KEY,
    stage_name VARCHAR(255)
);

-- Table for users.csv
CREATE TABLE users (
    id INT PRIMARY KEY,
    name VARCHAR(255),
    email VARCHAR(255),
    modified TIMESTAMP
);
